#' Snowflake connection parameter configuration
#'
#' Reads Snowflake connection parameters from the `connections.toml` and
#' `config.toml` files used by the [Python Connector for
#' Snowflake](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect)
#' and the [Snowflake
#' CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections),
#' or specifies them for a connection manually.
#'
#' # Common parameters
#'
#' The following is a list of common connection parameters. A more complete list
#' can be found in [Snowflake's documentation for the Python
#' Connector](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api#label-snowflake-connector-methods-connect):
#'
#' - `account`: A Snowflake account identifier.
#' - `user`: A Snowflake username.
#' - `role`: The role to use for the connection.
#' - `schema`: The default schema to use for the connection.
#' - `database`: The default database to use for the connection.
#' - `warehouse`: The default warehouse to use for the connection.
#' - `authenticator`: The authentication method to use for the connection.
#' - `private_key` or `private_key_file`: A path to a PEM-encoded private key
#'    for key-pair authentication.
#' - `private_key_file_pwd`: The passphrase for the private key, if any.
#' - `token`: The OAuth token to use for authentication.
#' - `token_file_path`: A path to an OAuth token to use for authentication.
#' - `password`: The user's Snowflake password.
#'
#' @param name A named connection. Defaults to
#'   `$SNOWFLAKE_DEFAULT_CONNECTION_NAME` if set, the `default_connection_name`
#'   from the `config.toml` file (if present), and finally the `[default]`
#'   section of the `connections.toml` file, if any. See [Snowflake's
#'   documentation](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#setting-a-default-connection)
#'   for details.
#' @param ... Additional connection parameters. See **Common parameters**.
#' @param .config_dir The directory to search for a `connections.toml` and
#'   `config.toml` file. Defaults to `$SNOWFLAKE_HOME` or `~/.snowflake` if that
#'   directory exists, otherwise it falls back to a platform-specific default.
#'   See [Snowflake's
#'   documentation](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#connecting-using-the-connections-toml-file)
#'   for details.
#'
#' @returns An object of class `"snowflake_connection"`.
#' @examples
#' \dontrun{
#' # Read the default connection parameters from an existing
#' # connections.toml file:
#' conn <- snowflake_connection()
#'
#' # Read a named connection from an existing connections.toml file:
#' conn <- snowflake_connection(name = "default")
#'
#' # Override specific parameters for a connection:
#' conn <- snowflake_connection(
#'   schema = "myschema",
#'   warehouse = "mywarehouse"
#' )
#' }
#' @examples
#' \dontrun{
#' # Pass connection parameters manually, which is useful if there is no
#' # connections.toml file. For example, to use key-pair authentication:
#' conn <- snowflake_connection(
#'   account = "myaccount",
#'   user = "me",
#'   private_key = "rsa_key.p8"
#' )
#' }
#' @export
snowflake_connection <- function(name = NULL, ..., .config_dir = NULL) {
  config_dir <- .config_dir %||% default_config_dir()

  cfg <- load_snowflake_config(name, config_dir)
  connections <- cfg$connections
  # if no configuration file is returned from loading config,
  # suggest creating connections.toml
  cfile <- cfg$connection_file %||% file.path(config_dir, "connections.toml")
  name <- name %||% cfg$connection_name

  # user provided connection name doesn't exist
  if (!is.null(name) && is.null(connections[[name]])) {
    cli::cli_abort(c(
      "Unknown connection {.str {name}}.",
      i = "Try defining a {.field [{name}]} section in {.file {cfile}} or
             omit the {.arg name} parameter to use the default connection
             instead."
    ))
  }

  # create list of connection parameters from file
  params <- c(list(name = name), connections[[name]])

  # TODO: Load generic environment variables
  # https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-environment-variables-for-snowflake-credentials

  # overwrite connection parameters with user-supplied values
  params <- utils::modifyList(params, list(...))
  name <- name %||% "default"
  # user prvovides connection info that doesn't include account
  if (is_empty(params$account)) {
    cli::cli_abort(c(
      "An {.arg account} parameter is required when {.file {cfile}} is missing
       or empty.",
      i = "Pass {.arg account} or define a {.field [{name}]} section with an
           {.field account} field in {.file {cfile}}."
    ))
  }

  # Fixup the authenticator if necessary.
  params$authenticator <- params$authenticator %||% "snowflake"
  if (!is_empty(params$private_key) || !is_empty(params$private_key_file)) {
    params$authenticator <- "SNOWFLAKE_JWT"
  }

  if (
    params$authenticator == "oauth" &&
      is.null(params$token) &&
      is.null(params$token_file_path)
  ) {
    cli::cli_abort(c(
      "One of {.arg token} or {.arg token_file_path} is required when using
       OAuth authentication."
    ))
  }

  if (params$authenticator == "SNOWFLAKE_JWT" && is.null(params$user)) {
    cli::cli_abort(c(
      "A {.arg user} parameter is required when using key-pair
       authentication."
    ))
  }

  # TODO: Should we check the types of parameters here?

  # Redact sensitive data.
  params$password <- redact(params[["password"]])
  params$token <- redact(params[["token"]])
  params$private_key_file_pwd <- redact(params[["private_key_file_pwd"]])

  structure(params, class = c("snowflake_connection", "list"))
}

#' @export
print.snowflake_connection <- function(x, ...) {
  params <- x[which(names(x) != "name")]
  labels <- lapply(
    names(params),
    function(x) cli::format_inline("{.field {x}}")
  )
  items <- lapply(params, function(x) {
    if (inherits(x, "snowflake_redacted")) {
      return(cli::col_grey("<REDACTED>"))
    }
    cli::format_inline("{.val {x}}")
  })
  if (!is.null(x$name)) {
    cli::cli_text("<Snowflake connection: {x$name}>\n")
  } else {
    cli::cli_text("<Snowflake connection>\n")
  }
  cli::cli_dl(items, labels = labels)
  invisible(x)
}

redact <- function(x) {
  if (!is_empty(x)) {
    class(x) <- c("snowflake_redacted", class(x))
  }
  x
}

#' @export
print.snowflake_redacted <- function(x, ...) {
  cat(cli::col_grey("<REDACTED>"))
}


#' Load Snowflake configuration
#'
#' Internal function that consolidates the loading and parsing of Snowflake
#' configuration files. This handles both `connections.toml` and `config.toml`
#' files, resolves the connection name, and returns a structured configuration.
#'
#' @param name A named connection to use. If NULL, the default connection will be used
#'   according to Snowflake client behavior.
#' @param config_dir The directory containing Snowflake configuration files.
#'   Defaults to the result of `default_config_dir()`.
#'
#' @return A list with the following components:
#'   \item{connections}{List of available connection configurations}
#'   \item{connection_name}{The resolved connection name to use}
#'   \item{connection_file}{Path to the configuration file that was loaded}
#'
#' @keywords internal
load_snowflake_config <- function(
  name = NULL,
  config_dir = default_config_dir()
) {
  # Initialize return structure
  result <- list(
    connections = NULL,
    connection_name = NULL,
    connection_file = NULL
  )

  # Paths to possible configuration files
  config_toml <- file.path(config_dir, "config.toml")
  connections_toml <- file.path(config_dir, "connections.toml")

  # Set connection name by priority: explicit name > environment variable > NULL
  result$connection_name <- name
  if (is.null(result$connection_name)) {
    env_connection_name <- Sys.getenv("SNOWFLAKE_DEFAULT_CONNECTION_NAME", "")
    if (nzchar(env_connection_name)) {
      result$connection_name <- env_connection_name
    }
  }

  # TODO: load environment variable overrides for connection parameters
  # `SNOWFLAKE_CONNECTIONS_` prefix

  # Load configuration files if they exist
  has_config_toml <- file.exists(config_toml)
  has_connections_toml <- file.exists(connections_toml)

  # Load config.toml if it exists
  if (has_config_toml) {
    config <- RcppTOML::parseTOML(config_toml, fromFile = TRUE)
    # If no connection name yet, check for default_connection_name
    if (
      is.null(result$connection_name) &&
        !is.null(config$default_connection_name)
    ) {
      result$connection_name <- config$default_connection_name
    }
  }

  # Load connections.toml if it exists
  if (has_connections_toml) {
    connections <- RcppTOML::parseTOML(connections_toml, fromFile = TRUE)
    result$connection_file <- connections_toml

    # If both files exist, inform user we're using connections.toml
    if (has_config_toml) {
      cli::cli_inform(c(
        "!" = "Both {.file {connections_toml}} and {.file {config_toml}} exist.
        Using {.file {connections_toml}}."
      ))

      # If we have a connection name from config.toml, verify it exists in connections.toml
      if (
        !is.null(result$connection_name) &&
          is.null(connections[[config$default_connection_name]])
      ) {
        cli::cli_abort(c(
          "{.field default_connection_name} is set to {.str {result$connection_name}} in
          {.file {config_toml}}, but the connection does not exist in
          {.file {connections_toml}}.",
          i = "Try defining a {.field [{result$connection_name}]} section in {.file {connections_toml}}."
        ))
      } else if (
        !is.null(result$connection_name) &&
          is.null(connections[[result$connection_name]])
      ) {
        cli::cli_abort(c(
          "Unknown connection {.str {result$connection_name}} in {.file {connections_toml}}.",
          i = "Try defining a {.field [{result$connection_name}]} section in {.file {connections_toml}}."
        ))
      }
    }
    # Set connections in result
    result$connections <- connections
    if (
      !is.null(connections[["default"]]) &&
        is.null(result$connection_name)
    ) {
      result$connection_name <- "default"
    }
  } else if (has_config_toml) {
    # Using config.toml only - get connections section if it exists
    if (!is.null(config$connections)) {
      connections <- config$connections
    }
    result$connection_file <- config_toml
  }

  result
}

#' Get the default Snowflake configuration directory
# See: https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#connecting-using-the-connections-toml-file
#'
#' @param os Operating system identifier; one of "win", "mac", or "unix".
#'   If NULL (the default), the value is determined automatically.
#'
#' @return Path to the default Snowflake configuration directory
#' @keywords internal
default_config_dir <- function(os = NULL) {
  # Check environment variables first
  home <- Sys.getenv("SNOWFLAKE_HOME", "~/.snowflake")
  if (dir.exists(home)) {
    return(home)
  }

  xdg_home <- Sys.getenv("XDG_CONFIG_HOME")
  if (nzchar(xdg_home)) {
    return(file.path(xdg_home, "snowflake"))
  }

  # Detect OS if not provided
  if (is.null(os)) {
    os <- if (.Platform$OS.type == "windows") "win" else if (
      Sys.info()["sysname"] == "Darwin"
    )
      "mac" else "unix"
  }

  # OS-specific paths
  os_paths <- list(
    win = file.path(Sys.getenv("LOCALAPPDATA"), "snowflake"),
    mac = "~/Library/Application Support/snowflake",
    unix = "~/.config/snowflake"
  )

  os_paths[[os]]
}


has_a_default_connection <- function(...) {
  tryCatch(
    {
      snowflake_connection(...)
      TRUE
    },
    error = function(e) FALSE
  )
}
