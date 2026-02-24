workload_identity_credentials <- function(
  params,
  cache = session_cache(params)
) {
  account <- params[["account"]]
  token <- params[["token"]]
  token_file_path <- params[["token_file_path"]]
  provider <- params[["workload_identity_provider"]]

  if (provider != "OIDC") {
    cli::cli_abort("Unsupported Workload Identity provider {.str {provider}}.")
  }

  # Check for a cached session first.
  cached <- cache$get()
  if (!is.null(cached)) {
    if (!has_expired(cached$expires_at)) {
      return(
        list(
          Authorization = sprintf('Snowflake Token="%s"', cached$token)
        )
      )
    }

    # If the session token has expired but the master token is still valid,
    # attempt to refresh the session.
    if (!has_expired(cached$master_expires_at)) {
      renewed <- tryCatch(
        renew_session(account, cached),
        error = function(e) NULL
      )
      if (!is.null(renewed)) {
        # Cache the renewed session
        cache$set(renewed)
        return(
          list(
            Authorization = sprintf('Snowflake Token="%s"', renewed$token)
          )
        )
      }
    }
  }

  # Read the token from the token file if provided. This silently overwrites any
  # inline token parameter, matching the behavior of the Python connector. We
  # also skip any whitespace cleanup, again matching the Python connector.
  if (!is.null(token_file_path)) {
    token <- tryCatch(
      readChar(token_file_path, file.info(token_file_path)$size),
      error = function(e) {
        cli::cli_abort(
          "Failed to read token from {.file {token_file_path}}.",
          parent = e
        )
      }
    )
    if (nchar(token) == 0) {
      cli::cli_abort("Token file {.file {token_file_path}} is empty.")
    }
  }

  # Exchange the OIDC token for session token.
  session <- login_request(
    account,
    data = list(
      AUTHENTICATOR = "WORKLOAD_IDENTITY",
      PROVIDER = provider,
      TOKEN = token
    )
  )

  # Cache the session.
  cache$set(session)

  return(
    list(
      Authorization = sprintf('Snowflake Token="%s"', session$token)
    )
  )
}
