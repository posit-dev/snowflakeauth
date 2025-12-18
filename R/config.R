#' Snowflake connection parameter configuration
#'
#' Reads Snowflake connection parameters from the `connections.toml` and
#' `config.toml` files used by the [Snowflake Connector for
#' Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect)
#' and the [Snowflake
#' CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections),
#' or specifies them for a connection manually.
#'
#' # Common parameters
#'
#' The following is a list of common connection parameters. A more complete list
#' can be found in the [documentation for the
#' Snowflake Connector for Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api#label-snowflake-connector-methods-connect):
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
#' @param .verbose Logical; if `TRUE`, prints detailed information about
#'   configuration loading, including which files are read and how connection
#'   parameters are resolved. Defaults to `FALSE`.
#'
#' @returns An object of class `"snowflake_connection"`.
#' @examplesIf has_a_default_connection()
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
#' @examples
#' # Pass connection parameters manually, which is useful if there is no
#' # connections.toml file. For example, to use key-pair authentication:
#' conn <- snowflake_connection(
#'   account = "myaccount",
#'   user = "me",
#'   private_key = "rsa_key.p8"
#' )
#' @export
snowflake_connection <- function(
  name = NULL,
  ...,
  .config_dir = NULL,
  .verbose = FALSE
) {
  # Load configuration
  config_dir <- .config_dir %||% default_config_dir()

  if (.verbose) {
    cli::cli_inform(c(
      "i" = "Loading Snowflake configuration from: {.path {config_dir}}"
    ))
  }

  cfg <- load_config(name, config_dir, .verbose = .verbose)

  # Extract connection data
  connections <- cfg$connections
  connection_name <- cfg$connection_name
  connection_file <- cfg$connection_file %||%
    file.path(config_dir, "connections.toml")

  # Error if the specified connection doesn't exist
  if (!is.null(connection_name) && is.null(connections[[connection_name]])) {
    cli::cli_abort(c(
      "Unknown connection {.str {connection_name}}.",
      i = "Try defining a {.field [{connection_name}]} section in {.file {connection_file}} or
           omit the {.arg name} parameter to use the default connection instead."
    ))
  }

  # Initialize params with connection from config
  params <- list(name = connection_name)
  if (!is.null(connection_name) && !is.null(connections[[connection_name]])) {
    params <- c(params, connections[[connection_name]])
  }

  # Override with explicitly provided parameters
  params <- utils::modifyList(params, list(...))

  # Validate that account is provided
  if (is_empty(params$account)) {
    cli::cli_abort(c(
      "An {.arg account} parameter is required when {.file {connection_file}} is missing or empty.",
      i = "Pass {.arg account} or define a {.field [{connection_name}]} section with an {.field account} field in {.file {connection_file}}."
    ))
  }

  # Setup authenticator
  params$authenticator <- params$authenticator %||% "snowflake"
  if (
    !is_empty(params$private_key) ||
      !is_empty(params$private_key_file) ||
      !is_empty(params$private_key_path)
  ) {
    params$authenticator <- "SNOWFLAKE_JWT"
  }

  # Validate OAuth configuration
  if (
    params$authenticator == "oauth" &&
      is.null(params$token) &&
      is.null(params$token_file_path)
  ) {
    cli::cli_abort(c(
      "One of {.arg token} or {.arg token_file_path} is required when using OAuth authentication."
    ))
  }

  # Validate key-pair authentication
  if (params$authenticator == "SNOWFLAKE_JWT" && is.null(params$user)) {
    cli::cli_abort(c(
      "A {.arg user} parameter is required when using key-pair authentication."
    ))
  }

  # Redact sensitive data
  params$password <- redact(params[["password"]])
  params$token <- redact(params[["token"]])
  params$private_key_file_pwd <- redact(params[["private_key_file_pwd"]])

  # Return structured connection object
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


#' Load Snowflake configuration from all available sources
#'
#' Loads and consolidates Snowflake configuration from multiple sources with proper
#' precedence handling. Configuration sources include:
#'
#' 1. `connections.toml` and `config.toml` files
#' 2. Environment variables (both generic and connection-specific)
#' 3. User-provided parameters
#'
#' The function follows Snowflake's client behavior for resolving connection names
#' and handling conflicts between configuration sources.
#'
#' @param name A named connection to use. If NULL, the default connection will be used
#' @param config_dir The directory containing Snowflake configuration files.
#'   Defaults to the result of `default_config_dir()`.
#' @param .verbose Logical; if TRUE, prints detailed information about
#'   configuration loading process.
#'
#' @return A list with the following components:
#'   \item{connections}{List of available connection configurations}
#'   \item{connection_name}{The resolved connection name to use}
#'   \item{connection_file}{Path to the configuration file that was loaded}
#'
#' @keywords internal
#' @noRd
load_config <- function(
  name = NULL,
  config_dir = default_config_dir(),
  .verbose = FALSE
) {
  # Initialize result structure
  result <- list(
    connections = list(),
    connection_name = NULL,
    connection_file = NULL
  )

  # File paths
  config_toml <- file.path(config_dir, "config.toml")
  connections_toml <- file.path(config_dir, "connections.toml")

  # Step 1: Resolve connection name with proper precedence:
  # 1. Explicit name parameter
  # 2. SNOWFLAKE_DEFAULT_CONNECTION_NAME environment variable
  # 3. default_connection_name from config.toml
  # 4. "default" section in connections.toml

  # Set from explicit parameter if provided
  if (!is.null(name)) {
    result$connection_name <- name
    if (.verbose) {
      cli::cli_inform(c(
        "i" = "Using connection name from parameter: {.str {name}}"
      ))
    }
  } else {
    # Check environment variable
    env_connection_name <- Sys.getenv("SNOWFLAKE_DEFAULT_CONNECTION_NAME", "")
    if (nzchar(env_connection_name)) {
      result$connection_name <- env_connection_name
      if (.verbose) {
        cli::cli_inform(c(
          "i" = "Using connection name from SNOWFLAKE_DEFAULT_CONNECTION_NAME: {.str {env_connection_name}}"
        ))
      }
    }
  }

  has_config_toml <- file.exists(config_toml)
  has_connections_toml <- file.exists(connections_toml)

  if (has_config_toml) {
    if (.verbose) {
      cli::cli_inform(c("i" = "Found config.toml at: {.path {config_toml}}"))
    }
    config <- RcppTOML::parseTOML(config_toml, fromFile = TRUE)

    # If no connection name yet, get from config.toml
    if (
      is.null(result$connection_name) &&
        !is.null(config$default_connection_name)
    ) {
      result$connection_name <- config$default_connection_name
      if (.verbose) {
        cli::cli_inform(c(
          "i" = "Using default_connection_name from config.toml: {.str {config$default_connection_name}}"
        ))
      }
    }

    if (
      is.null(result$connection_name) &&
        "default" %in% names(config$connections)
    ) {
      result$connection_name <- "default"
      if (.verbose) {
        cli::cli_inform(c(
          "i" = "Found [default] section in config.toml"
        ))
      }
    }

    # Extract connections section if it exists
    if (!is.null(config$connections)) {
      result$connections <- config$connections
      result$connection_file <- config_toml
      if (.verbose) {
        cli::cli_inform(c(
          "i" = "Loaded {length(config$connections)} connection{?s} from config.toml"
        ))
      }
    }
  }

  # Load connections.toml (takes precedence if both exist)
  if (has_connections_toml) {
    if (.verbose) {
      cli::cli_inform(c(
        "i" = "Found connections.toml at: {.path {connections_toml}}"
      ))
    }
    connections <- RcppTOML::parseTOML(connections_toml, fromFile = TRUE)

    # If both files define connections, inform the user that connections.toml
    # takes precedence.
    if (length(result$connections) > 0 && length(connections) > 0) {
      cli::cli_inform(c(
        "!" = "Both {.file connections.toml} and {.file config.toml} define connections. {.file connections.toml} takes precedence."
      ))

      # Validate that connection name from config.toml exists in connections.toml
      if (
        !is.null(result$connection_name) &&
          result$connection_name != "default" &&
          is.null(connections[[result$connection_name]])
      ) {
        cli::cli_abort(c(
          "{.field default_connection_name} is set to {.str {result$connection_name}} in {.file config.toml},
          but the connection does not exist in {.file connections.toml}.",
          i = "Try defining a {.field [{result$connection_name}]} section in {.file connections.toml}."
        ))
      }
    }

    # Set connections in result
    result$connections <- connections
    result$connection_file <- connections_toml

    if (.verbose && length(connections) > 0) {
      cli::cli_inform(c(
        "i" = "Loaded {length(connections)} connection{?s} from connections.toml"
      ))
    }

    # Set default connection name if not already set and "default" exists
    if (is.null(result$connection_name) && !is.null(connections[["default"]])) {
      result$connection_name <- "default"
      if (.verbose) {
        cli::cli_inform(c(
          "i" = "Found [default] section in connections.toml"
        ))
      }
    }
  }

  # No configuration files found
  if (.verbose) {
    cli::cli_inform(c(
      "i" = "No configuration files found in: {.path {config_dir}}"
    ))
  }
  # Step 3: Process environment variables
  env_config <- parse_env_vars()

  if (.verbose && length(env_config) > 0) {
    env_names <- names(env_config)
    cli::cli_inform(c(
      "i" = "Found environment variables for connection{?s}: {.str {env_names}}"
    ))
  }

  # Apply environment variables to connections
  if (
    !is.null(result$connection_name) &&
      !is.null(env_config[[result$connection_name]])
  ) {
    # Apply connection-specific env vars
    if (is.null(result$connections[[result$connection_name]])) {
      result$connections[[result$connection_name]] <- list()
    }

    if (.verbose) {
      env_params <- names(env_config[[result$connection_name]])
      cli::cli_inform(c(
        "i" = "Applying environment variables for {.str {result$connection_name}}: {.field {env_params}}"
      ))
    }

    result$connections[[result$connection_name]] <- utils::modifyList(
      result$connections[[result$connection_name]],
      env_config[[result$connection_name]]
    )
  }

  # Apply generic environment variables if no specific connection exists
  if (is.null(result$connection_name) && !is.null(env_config$default)) {
    # Create a default connection from generic env vars
    result$connections$default <- env_config$default
    result$connection_name <- "default"

    if (.verbose) {
      cli::cli_inform(c(
        "i" = "Applying environment variables for default connection"
      ))
    }
  } else if (!is.null(env_config$default)) {
    # Apply generic env vars as fallback to specific connection
    if (!is.null(result$connection_name)) {
      if (is.null(result$connections[[result$connection_name]])) {
        result$connections[[result$connection_name]] <- env_config$default
      } else {
        # Only apply values that don't already exist in the connection
        applied_vars <- character()
        for (name in names(env_config$default)) {
          if (is.null(result$connections[[result$connection_name]][[name]])) {
            result$connections[[result$connection_name]][[
              name
            ]] <- env_config$default[[name]]
            applied_vars <- c(applied_vars, name)
          }
        }

        if (.verbose && length(applied_vars) > 0) {
          cli::cli_inform(c(
            "i" = "Applied environment variables: {.field {applied_vars}}"
          ))
        }
      }
    }
  }

  if (.verbose && !is.null(result$connection_name)) {
    cli::cli_inform(c(
      "i" = "Using connection name: {.str {result$connection_name}}"
    ))

    if (!is.null(result$connection_file)) {
      cli::cli_inform(c(
        "i" = "Using configuration from: {.path {result$connection_file}}"
      ))
    }
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
#' @noRd
default_config_dir <- function(os = NULL) {
  # Check environment variables first
  snowflake_home_env <- Sys.getenv("SNOWFLAKE_HOME")
  if (nzchar(snowflake_home_env)) {
    return(path.expand(snowflake_home_env))
  }

  snowflake_home <- path.expand("~/.snowflake")
  if (dir.exists(snowflake_home)) {
    return(snowflake_home)
  }

  xdg_home <- Sys.getenv("XDG_CONFIG_HOME")
  if (nzchar(xdg_home)) {
    return(file.path(xdg_home, "snowflake"))
  }

  # Detect OS if not provided
  if (is.null(os)) {
    os <- if (.Platform$OS.type == "windows") {
      "win"
    } else if (Sys.info()["sysname"] == "Darwin") {
      "mac"
    } else {
      "unix"
    }
  }

  # OS-specific paths
  os_paths <- list(
    win = file.path(Sys.getenv("LOCALAPPDATA"), "snowflake"),
    mac = "~/Library/Application Support/snowflake",
    unix = "~/.config/snowflake"
  )

  path.expand(os_paths[[os]])
}

#' Reports whether a default connection is available
#'
#' @param ... arguments passed to [snowflake_connection()]
#' @return Logical value indicating whether a default connection is available.
#' @export
#'
#' @examples
#' has_a_default_connection()
has_a_default_connection <- function(...) {
  tryCatch(
    {
      snowflake_connection(...)
      TRUE
    },
    error = function(e) FALSE
  )
}


#' Parse environment variables for Snowflake connections
#'
#' Extracts Snowflake connection parameters from environment variables
#'
#' Handles
#'
#' 1. Generic variables with `SNOWFLAKE_` prefix (e.g., `SNOWFLAKE_ACCOUNT`)
#' 2. Connection-specific variables with `SNOWFLAKE_CONNECTIONS_NAME_` prefix
#'    (e.g., `SNOWFLAKE_CONNECTIONS_PROD_ROLE`)
#'
#' @return A list containing parsed environment variables organized by connection name
#' @keywords internal
#' @noRd
parse_env_vars <- function() {
  # Get all environment variables
  env_vars <- Sys.getenv()
  result <- list()

  # Handle generic SNOWFLAKE_* variables
  # https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-environment-variables-for-snowflake-credentials
  generic_envvars <- c(
    "SNOWFLAKE_ACCOUNT",
    "SNOWFLAKE_USER",
    "SNOWFLAKE_PASSWORD",
    "SNOWFLAKE_DATABASE",
    "SNOWFLAKE_SCHEMA",
    "SNOWFLAKE_ROLE",
    "SNOWFLAKE_WAREHOUSE",
    "SNOWFLAKE_AUTHENTICATOR",
    "SNOWFLAKE_PRIVATE_KEY_PATH",
    "SNOWFLAKE_PRIVATE_KEY_FILE",
    "SNOWFLAKE_PRIVATE_KEY_RAW",
    "SNOWFLAKE_SESSION_TOKEN",
    "SNOWFLAKE_MASTER_TOKEN",
    "SNOWFLAKE_TOKEN_FILE_PATH",
    "SNOWFLAKE_OAUTH_CLIENT_ID",
    "SNOWFLAKE_OAUTH_CLIENT_SECRET",
    "SNOWFLAKE_OAUTH_AUTHORIZATION_URL",
    "SNOWFLAKE_OAUTH_TOKEN_REQUEST_URL",
    "SNOWFLAKE_OAUTH_REDIRECT_URI",
    "SNOWFLAKE_OAUTH_SCOPE",
    "SNOWFLAKE_OAUTH_DISABLE_PKCE",
    "SNOWFLAKE_OAUTH_ENABLE_REFRESH_TOKENS",
    "SNOWFLAKE_OAUTH_ENABLE_SINGLE_USE_REFRESH_TOKENS",
    "SNOWFLAKE_CLIENT_STORE_TEMPORARY_CREDENTIAL"
  )

  # Extract non-empty generic variables and convert to lowercase parameter names
  generic_vars <- env_vars[generic_envvars]
  generic_vars <- generic_vars[!is.na(generic_vars) & generic_vars != ""]

  if (length(generic_vars) > 0) {
    names(generic_vars) <- tolower(gsub("^SNOWFLAKE_", "", names(generic_vars)))
    result$default <- as.list(generic_vars)
  }

  # Handle SNOWFLAKE_CONNECTIONS_* variables for specific named connections
  connection_vars <- env_vars[grepl("^SNOWFLAKE_CONNECTIONS_", names(env_vars))]

  for (var_name in names(connection_vars)) {
    # Remove the SNOWFLAKE_CONNECTIONS_ prefix
    remaining <- sub("^SNOWFLAKE_CONNECTIONS_", "", var_name)

    # Split by underscores
    parts <- strsplit(remaining, "_", fixed = TRUE)[[1]]

    if (length(parts) >= 2) {
      # First part is the connection name (keep case)
      connection_name <- parts[1]

      # Remaining parts form the parameter name (convert to lowercase and join with underscores)
      param_name <- tolower(paste(parts[-1], collapse = "_"))

      # Initialize connection list if it doesn't exist
      if (is.null(result[[connection_name]])) {
        result[[connection_name]] <- list()
      }

      # Add the parameter
      result[[connection_name]][[param_name]] <- connection_vars[[var_name]]
    }
  }

  result
}
