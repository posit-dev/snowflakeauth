# Support for "external browser" SSO authentication, including an in-memory cache.
externalbrowser_credentials <- function(
  params,
  cache = session_cache(params)
) {
  account <- params$account
  user <- params$user
  if (!interactive()) {
    cli::cli_abort(c(
      "External browser authentication requires an interactive R session",
      "i" = "Use a different authenticator"
    ))
  }

  if (is_hosted_session()) {
    cli::cli_abort(c(
      "External browser authentication does not work in a hosted environment",
      "i" = "Use a different authenticator"
    ))
  }

  rlang::check_installed(
    "httpuv",
    reason = "for external browser authentication"
  )

  # This is a totally custom protocol that seems to be doubly-influenced by
  # SAML and OpenID Connect.

  # Check for a cached session before launching the browser flow.
  cached <- cache$get()
  if (!is.null(cached)) {
    if (!has_expired(cached$expires_at)) {
      return(list(
        Authorization = sprintf('Snowflake Token="%s"', cached$token)
      ))
    }

    # If the session token has expired but the master token is still valid,
    # attempt to refresh the session.
    if (!has_expired(cached$master_expires_at)) {
      tryCatch(
        {
          session <- renew_session(account, cached)
          session$id_token <- session$id_token %||% cached$id_token
          cache$set(session)
          return(list(
            Authorization = sprintf('Snowflake Token="%s"', session$token)
          ))
        },
        error = function(e) {
          NULL
        }
      )
    }

    # If we have a cached ID token, attempt to get a new session with it.
    #
    # This is only possible on Snowflake accounts that have opted into this.
    if (!has_expired(cached$id_token_expires_at)) {
      tryCatch(
        {
          session <- login_request(
            account,
            data = list(
              AUTHENTICATOR = "ID_TOKEN",
              TOKEN = cached$id_token
            )
          )
          cache$set(session)
          return(list(
            Authorization = sprintf('Snowflake Token="%s"', session$token)
          ))
        },
        error = function(e) {
          # Clear the now-invalid cache.
          cache$clear()
          NULL
        }
      )
    }
  }

  # Request the user's SSO URL and "proof key" from Snowflake.
  port <- httpuv::randomPort()
  result <- request_sso_url(account, user, port)
  sso_url <- result$sso_url
  proof_key <- result$proof_key

  # Open the SSO URL and listen for the redirect.
  utils::browseURL(sso_url)
  token <- localhost_listen(port)

  # Exchange the identity token and proof key for an authentication token.
  session <- login_request(
    account,
    data = list(
      AUTHENTICATOR = "EXTERNALBROWSER",
      TOKEN = token,
      PROOF_KEY = proof_key
    )
  )

  # Cache the session for headless refreshing (when possible).
  cache$set(session)

  return(list(
    Authorization = sprintf('Snowflake Token="%s"', session$token)
  ))
}

# Try to determine whether we can redirect the user's browser to a server on
# localhost, which isn't possible if we are running on a hosted platform.
#
# Currently this detects RStudio Server, Posit Workbench, and Google Colab. It
# is based on the strategy pioneered by the {gargle} package.
is_hosted_session <- function() {
  if (nzchar(Sys.getenv("COLAB_RELEASE_TAG"))) {
    return(TRUE)
  }
  # If RStudio Server or Posit Workbench is running locally (which is possible,
  # though unusual), it's not acting as a hosted environment.
  Sys.getenv("RSTUDIO_PROGRAM_MODE") == "server" &&
    !grepl("localhost", Sys.getenv("RSTUDIO_HTTP_REFERER"), fixed = TRUE)
}

request_sso_url <- function(account, user, callback_port) {
  url <- sprintf(
    "https://%s.snowflakecomputing.com/session/authenticator-request",
    account
  )
  body <- jsonlite::toJSON(
    list(
      data = list(
        ACCOUNT_NAME = NULL,
        LOGIN_NAME = user,
        AUTHENTICATOR = "EXTERNALBROWSER",
        BROWSER_MODE_REDIRECT_PORT = as.character(callback_port)
      )
    ),
    auto_unbox = TRUE
  )

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = body)
  curl::handle_setheaders(
    handle,
    `Content-Type` = "application/json",
    `Accept` = "application/json"
  )

  resp <- curl::curl_fetch_memory(url, handle)
  if (resp$status_code >= 400) {
    cli::cli_abort(c(
      "Failed to obtain SSO URL from Snowflake",
      i = "Status code: {.strong {resp$status_code}}",
    ))
  }

  content <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
  if (
    !isTRUE(content$success) ||
      is.null(content[["data"]]) ||
      is.null(content[["data"]][["ssoUrl"]]) ||
      is.null(content[["data"]][["proofKey"]])
  ) {
    cli::cli_abort(
      "Received unexpected response body while obtaining SSO URL from Snowflake",
    )
  }

  list(
    sso_url = content[["data"]][["ssoUrl"]],
    proof_key = content[["data"]][["proofKey"]]
  )
}

localhost_listen <- function(port) {
  token <- NULL
  done <- FALSE

  listen <- function(req) {
    if (!identical(req$PATH_INFO, "/") || req$REQUEST_METHOD != "GET") {
      return(list(
        status = 404L,
        headers = list("Content-Type" = "text/plain"),
        body = "Not found"
      ))
    }

    if (!is.character(req$QUERY_STRING)) {
      done <<- TRUE
      return(list(
        status = 400L,
        headers = list("Content-Type" = "text/plain"),
        body = "Missing token parameter"
      ))
    }

    # Note: we might want to actual parse the query string properly here.
    # But for now, take advantage of the fact that it will only contain
    # one parameter.
    token <<- gsub("\\?token=([^&]+)", "\\1", req$QUERY_STRING)
    done <<- TRUE

    list(
      status = 200L,
      headers = list("Content-Type" = "text/plain"),
      body = "Authentication complete. Please close this page and return to R."
    )
  }

  server <- httpuv::startServer("127.0.0.1", port, list(call = listen))
  on.exit(httpuv::stopServer(server), add = TRUE)

  rlang::inform("Waiting for authentication in browser...")
  rlang::inform("Press Esc/Ctrl + C to abort")
  while (!done) {
    httpuv::service()
  }
  httpuv::service()

  if (is.null(token)) {
    cli::cli_abort("Authentication failed")
  }

  token
}
