#' Get credentials for a Snowflake connection
#' @param params a list of connection parameters from `[snowflake_connection()]``
#' @param role a snowflake entity
#' @param spcs_endpoint a Snowpark Container Services ingress URL, formatted (*-accountname.snowflakecomputing.app)
#' @param ... Additional Snowflake connection parameters
#'
#' @returns A list of HTTP headers.
#' @export
#' @examplesIf has_a_default_connection() && interactive()
#' # Obtain authentication headers for accessing Snowflake APIs
#' snowflake_credentials(
#'  snowflake_connection()
#' )
#' @examplesIf has_a_default_connection() && interactive()
#' # If the application is in Snowpark Container Services,
#' # a different collection of headers are returned:
#' snowflake_credentials(
#'  snowflake_connection(),
#'  spcs_endpoint = "https://example-accountname.snowflakecomputing.app"
#' )
snowflake_credentials <- function(
  params,
  role = NULL,
  spcs_endpoint = NULL,
  ...
) {
  role <- role %||% params$role
  switch(
    params$authenticator,
    oauth = oauth_credentials(
      params$account,
      params$token,
      params$token_file_path,
      spcs_endpoint
    ),
    SNOWFLAKE_JWT = keypair_credentials(
      params$account,
      params$user,
      params$private_key_file %||%
        params$private_key %||%
        params$private_key_path,
      params$private_key_file_pwd,
      spcs_endpoint,
      role
    ),
    externalbrowser = externalbrowser_credentials(params),
    cli::cli_abort(c(
      "Unsupported authenticator: {.str {params$authenticator}}.",
      "i" = "Supported authenticators: oauth, SNOWFLAKE_JWT, externalbrowser"
    ))
  )
}

formEncode <- function(form_data) {
  paste0(
    curl::curl_escape(names(form_data)),
    "=",
    curl::curl_escape(form_data),
    collapse = "&"
  )
}

# In-memory cache for Snowflake sessions. Analogous to httr2:::cache_mem().
session_cache <- function(params) {
  key <- rlang::hash(params)
  list(
    get = function() rlang::env_get(the$session_cache, key, default = NULL),
    set = function(session) rlang::env_poke(the$session_cache, key, session),
    clear = function() rlang::env_unbind(the$session_cache, key)
  )
}

# Wrap a Snowflake session response into an S3 object.
snowflake_session <- function(data, .now = Sys.time()) {
  # The actual token field has different field names depending on the endpoint.
  token <- data[["token"]] %||% data[["sessionToken"]]

  if (is.null(token)) {
    cli::cli_abort(
      "Unexpected response body: missing session token"
    )
  }

  expires_at <- as.numeric(.now) + data[["validityInSeconds"]]

  # Don't store expiry for tokens we don't have.
  master_expires_at <- NULL
  if (!is.null(data[["masterToken"]])) {
    master_expires_at <- as.numeric(.now) + data[["masterValidityInSeconds"]]
  }
  id_token_expires_at <- NULL
  if (!is.null(data[["idToken"]])) {
    id_token_expires_at <- as.numeric(.now) + data[["idTokenValidityInSeconds"]]
  }

  structure(
    # Drop NULL fields via Filter.
    Filter(
      length,
      list(
        id = data[["sessionId"]],
        token = token,
        expires_at = expires_at,
        master_token = data[["masterToken"]],
        master_expires_at = master_expires_at,
        id_token = data[["idToken"]],
        id_token_expires_at = id_token_expires_at,
        info = data[["sessionInfo"]]
      )
    ),
    class = "snowflake_session"
  )
}

# Check if a token timestamp will expire "in the next five minutes".
has_expired <- function(expires_at, .now = Sys.time()) {
  is.null(expires_at) || (as.integer(.now) + 5L) > expires_at
}

# Generic helper for calls to the /login-request endpoint.
login_request <- function(account, data, extra_headers = list()) {
  url <- sprintf(
    "https://%s.snowflakecomputing.com/session/v1/login-request",
    account
  )
  body <- jsonlite::toJSON(list(data = data), auto_unbox = TRUE)
  headers <- c(
    extra_headers,
    `Content-Type` = "application/json",
    `Accept` = "application/json"
  )

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = body)
  curl::handle_setheaders(handle, .list = headers)

  resp <- curl::curl_fetch_memory(url, handle)
  if (resp$status_code >= 400) {
    cli::cli_abort(c(
      "Snowflake login request failed",
      i = "Status code: {.strong {resp$status_code}}"
    ))
  }

  content <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
  if (!isTRUE(content$success) || is.null(content$data)) {
    cli::cli_abort("Received unexpected response during login request")
  }

  snowflake_session(content$data)
}

# Renew an existing Snowflake session using its "master" token.
renew_session <- function(account, session) {
  url <- sprintf(
    "https://%s.snowflakecomputing.com/session/token-request",
    account
  )
  body <- jsonlite::toJSON(
    list(
      oldSessionToken = session$token,
      requestType = "RENEW"
    ),
    auto_unbox = TRUE
  )

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = body)
  curl::handle_setheaders(
    handle,
    `Content-Type` = "application/json",
    `Accept` = "application/json",
    `Authorization` = sprintf('Snowflake Token="%s"', session$master_token)
  )

  resp <- curl::curl_fetch_memory(url, handle)
  if (resp$status_code >= 400) {
    cli::cli_abort(c(
      "Failed to renew session",
      i = "Status code: {.strong {resp$status_code}}"
    ))
  }

  content <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
  if (!isTRUE(content$success) || is.null(content$data)) {
    cli::cli_abort(
      "Received unexpected response while renewing session"
    )
  }

  renewed <- snowflake_session(content$data)
  # TODO: This might not be necessary.
  renewed$id_token <- renewed$id_token %||% session$id_token
  renewed
}
