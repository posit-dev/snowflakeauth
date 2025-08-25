oauth_credentials <- function(
  account,
  token = NULL,
  token_file = NULL,
  spcs_endpoint = NULL
) {
  if (!is.null(token_file)) {
    tryCatch(
      token <- readLines(token_file, warn = FALSE, encoding = "UTF-8"),
      error = function(e) {
        cli::cli_abort(
          "Failed to read OAuth token from {.file {token_file}}.",
          parent = e
        )
      }
    )
  }
  if (is.null(spcs_endpoint)) {
    return(list(
      Authorization = paste("Bearer", token),
      `X-Snowflake-Authorization-Token-Type` = "OAUTH"
    ))
  }
  if (grepl("^https?://", spcs_endpoint)) {
    spcs_endpoint <- sub("^https?://", "", spcs_endpoint)
  }

  account_url <- sprintf("https://%s.snowflakecomputing.com", account)
  session_token <- exchange_oauth_token(account_url, token, spcs_endpoint)

  return(list(
    Authorization = sprintf('Snowflake Token="%s"', session_token$token)
  ))
}

exchange_oauth_token <- function(account_url, token, spcs_endpoint) {
  url <- sprintf("%s/session/v1/login-request", account_url)
  payload <- list(
    data = list(
      TOKEN = token,
      AUTHENTICATOR = "OAUTH"
    )
  )

  json_body <- jsonlite::toJSON(payload, auto_unbox = TRUE)

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = json_body)
  curl::handle_setheaders(
    handle,
    `Content-Type` = "application/json",
    `Accept` = "application/json",
    `X-Snowflake-Authorization-Token-Type` = "OAUTH",
    `Authorization` = paste("Bearer", token)
  )
  resp <- curl::curl_fetch_memory(url, handle)

  if (resp$status_code >= 400) {
    cli::cli_abort(c(
      "Could not exchange OAuth token",
      "Status code: {.strong {resp$status_code}}",
      "Response: {rawToChar(resp$content)}"
    ))
  }

  resp_json_content <- jsonlite::fromJSON(
    rawToChar(resp$content),
    simplifyVector = FALSE
  )
  if (is.null(resp_json_content[["data"]][["token"]])) {
    cli::cli_abort(
      "Unexpected response from server: {rawToChar(resp$content)}"
    )
  }
  list(token = resp_json_content[["data"]][["token"]])
}
