workload_identity_credentials <- function(
  params,
  cache = session_cache(params)
) {
  account <- params$account
  token <- params$token
  token_file_path <- params$token_file_path
  provider <- params$provider %||% "OIDC"

  # Check for a cached session first
  cached <- cache$get()
  if (!is.null(cached)) {
    # If session token is still valid, return it immediately
    if (!has_expired(cached$expires_at)) {
      return(list(
        Authorization = sprintf('Snowflake Token="%s"', cached$token)
      ))
    }

    # If session token expired but master token is still valid, renew the session
    if (!has_expired(cached$master_expires_at)) {
      renewed <- tryCatch(
        renew_session(account, cached),
        error = function(e) {
          NULL
        }
      )
      if (!is.null(renewed)) {
        # Cache the renewed session
        cache$set(renewed)
        return(list(
          Authorization = sprintf('Snowflake Token="%s"', renewed$token)
        ))
      }
    }
  }

  # Read token from file if provided
  if (!is.null(token_file_path)) {
    tryCatch(
      token <- readLines(token_file_path, warn = FALSE, encoding = "UTF-8"),
      error = function(e) {
        cli::cli_abort(
          "Failed to read token from {.file {token_file_path}}.",
          parent = e
        )
      }
    )
  }

  # Exchange token for session token
  session <- login_request(
    account,
    data = list(
      AUTHENTICATOR = "WORKLOAD_IDENTITY",
      PROVIDER = provider,
      TOKEN = token
    )
  )

  # Cache the session
  cache$set(session)

  # Return authorization header
  return(list(
    Authorization = sprintf('Snowflake Token="%s"', session$token)
  ))
}
