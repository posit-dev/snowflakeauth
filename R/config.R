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
  params <- list(name = name)
  config_dir <- .config_dir %||% default_config_dir()
  cfile <- file.path(config_dir, "connections.toml")

  # TODO: How should we distinguish "no ambient Snowflake credentials" here?

  if (file.exists(cfile)) {
    connections <- RcppTOML::parseTOML(cfile, fromFile = TRUE)
    if (!is.null(name) && is.null(connections[[name]])) {
      cli::cli_abort(c(
        "Unknown connection {.str {name}}.",
        i = "Try defining a {.field [{name}]} section in {.file {cfile}} or
             omit the {.arg name} parameter to use the default connection
             instead."
      ))
    }
    name <- name %||% default_connection_name(config_dir)
    if (is.null(connections[[name]])) {
      cli::cli_abort(c(
        "The default connection is missing.",
        i = "Try defining a {.field [{name}]} section in {.file {cfile}}."
      ))
    }
    params <- c(list(name = name), connections[[name]])
    if (is_empty(params$account)) {
      cli::cli_abort(c(
        "The {.field {name}} connection is missing the required
        {.field account} field.",
        i = "Try defining an {.field account} in the {.field [{name}]} section
            of {.file {cfile}}."
      ))
    }
  }

  # TODO: Should we check for conflicts in the account parameter, e.g. if
  # SNOWFLAKE_ACCOUNT differs from the connection's account?

  params <- utils::modifyList(params, list(...))
  if (is_empty(params$account)) {
    name <- name %||% default_connection_name(config_dir)
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

# See: https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#connecting-using-the-connections-toml-file
default_config_dir <- function(os = NULL) {
  home <- Sys.getenv("SNOWFLAKE_HOME", "~/.snowflake")
  if (dir.exists(home)) {
    return(home)
  }
  if (nzchar(env <- Sys.getenv("XDG_CONFIG_HOME"))) {
    return(file.path(env, "snowflake"))
  }
  # System-specific paths.
  if (is.null(os)) {
    if (.Platform$OS.type == "windows") {
      os <- "win"
    } else if (Sys.info()["sysname"] == "Darwin") {
      os <- "mac"
    } else {
      os <- "unix"
    }
  }
  switch(
    os,
    win = file.path(Sys.getenv("LOCALAPPDATA"), "snowflake"),
    mac = "~/Library/Application Support/snowflake",
    unix = "~/.config/snowflake"
  )
}

# See: https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#setting-a-default-connection
default_connection_name <- function(config_dir = default_config_dir()) {
  # The environment variable takes precedence.
  if (nzchar(env <- Sys.getenv("SNOWFLAKE_DEFAULT_CONNECTION_NAME"))) {
    return(env)
  }
  name <- "default"
  cfg <- file.path(config_dir, "config.toml")
  if (file.exists(cfg)) {
    cfg <- RcppTOML::parseTOML(cfg, fromFile = TRUE)
    name <- cfg$default_connection_name %||% name
  }
  name
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
