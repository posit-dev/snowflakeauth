oauth_authorization_code_credentials <- function(
  params,
  cache = session_cache(params)
) {
  account <- params$account
  user <- params$user
  host <- params$host

  # Check for a cached session before launching the browser flow.
  cached <- cache$get()
  if (!is.null(cached)) {
    if (!has_expired(cached$expires_at)) {
      return(
        list(
          Authorization = sprintf('Snowflake Token="%s"', cached$token)
        )
      )
    }

    if (!has_expired(cached$master_expires_at)) {
      tryCatch(
        {
          session <- renew_session(account, cached, host = host)
          cache$set(session)
          return(
            list(
              Authorization = sprintf('Snowflake Token="%s"', session$token)
            )
          )
        },
        error = function(e) {
          NULL
        }
      )
    }
  }

  base_url <- snowflake_url(host, account)
  client_id <- "LOCAL_APPLICATION"
  client_secret <- "LOCAL_APPLICATION"
  token_url <- params$oauth_token_request_url %||%
    paste0(base_url, "/oauth/token-request")
  scope <- build_scope(params$oauth_scope, params$role)

  # Try refresh token from keyring.
  keyring_user <- user %||% account
  if (use_keyring()) {
    cached_refresh <- keyring_get_token(
      account,
      keyring_user,
      "OAUTH_REFRESH_TOKEN"
    )
    if (!is.null(cached_refresh)) {
      tryCatch(
        {
          tokens <- request_oauth_tokens(
            token_url,
            grant_type = "refresh_token",
            client_id = client_id,
            client_secret = client_secret,
            refresh_token = cached_refresh$token,
            scope = scope
          )
          session <- login_request(
            account,
            user = user,
            data = list(AUTHENTICATOR = "OAUTH", TOKEN = tokens$access_token),
            host = host
          )
          cache$set(session)
          # Update refresh token if a new one was issued.
          if (!is.null(tokens$refresh_token)) {
            keyring_cache_token(
              account,
              keyring_user,
              "OAUTH_REFRESH_TOKEN",
              tokens$refresh_token,
              as.numeric(Sys.time()) + (90 * 24 * 60 * 60)
            )
          }
          return(
            list(
              Authorization = sprintf('Snowflake Token="%s"', session$token)
            )
          )
        },
        error = function(e) {
          keyring_clear_token(account, keyring_user, "OAUTH_REFRESH_TOKEN")
          NULL
        }
      )
    }
  }

  # Full browser flow — requires interactive session and httpuv.
  if (!rlang::is_interactive()) {
    cli::cli_abort(
      c(
        "local OAuth authentication requires an interactive R session",
        "i" = "Use a different authenticator"
      )
    )
  }

  if (is_hosted_session()) {
    cli::cli_abort(
      c(
        "local OAuth authentication does not work in a hosted environment",
        "i" = "Use a different authenticator"
      )
    )
  }

  rlang::check_installed(
    "httpuv",
    reason = "for local OAuth authentication"
  )
  authorization_url <- params$oauth_authorization_url %||%
    paste0(base_url, "/oauth/authorize")

  pkce <- generate_pkce()
  state <- base64url_encode(openssl::rand_bytes(32))
  port <- httpuv::randomPort()
  redirect_uri <- sprintf("http://127.0.0.1:%d", port)

  auth_url <- build_authorization_url(
    authorization_url,
    client_id = client_id,
    redirect_uri = redirect_uri,
    code_challenge = pkce$challenge,
    state = state,
    scope = scope
  )

  utils::browseURL(auth_url)
  result <- oauth_code_listen(port)

  if (!identical(result$state, state)) {
    cli::cli_abort("OAuth state mismatch (possible CSRF attack)")
  }

  tokens <- request_oauth_tokens(
    token_url,
    grant_type = "authorization_code",
    client_id = client_id,
    client_secret = client_secret,
    code = result$code,
    redirect_uri = redirect_uri,
    code_verifier = pkce$verifier
  )

  session <- login_request(
    account,
    user = user,
    data = list(AUTHENTICATOR = "OAUTH", TOKEN = tokens$access_token),
    host = host
  )
  cache$set(session)

  # Cache refresh token for cross-session persistence.
  if (!is.null(tokens$refresh_token) && use_keyring()) {
    keyring_cache_token(
      account,
      keyring_user,
      "OAUTH_REFRESH_TOKEN",
      tokens$refresh_token,
      as.numeric(Sys.time()) + (90 * 24 * 60 * 60)
    )
  }

  list(Authorization = sprintf('Snowflake Token="%s"', session$token))
}

generate_pkce <- function() {
  verifier <- base64url_encode(openssl::rand_bytes(32))
  challenge <- base64url_encode(openssl::sha256(charToRaw(verifier)))
  list(verifier = verifier, challenge = challenge)
}

base64url_encode <- function(raw_bytes) {
  encoded <- openssl::base64_encode(raw_bytes)
  encoded <- gsub("+", "-", encoded, fixed = TRUE)
  encoded <- gsub("/", "_", encoded, fixed = TRUE)
  gsub("=", "", encoded, fixed = TRUE)
}

build_scope <- function(oauth_scope = NULL, role = NULL) {
  scope <- oauth_scope %||% ""
  if (!nzchar(scope) && !is.null(role)) {
    scope <- paste0("session:role:", role)
  }
  tokens <- if (nzchar(scope)) strsplit(trimws(scope), "\\s+")[[1]] else
    character()
  if (!("refresh_token" %in% tokens)) {
    tokens <- c(tokens, "refresh_token")
  }
  paste(tokens, collapse = " ")
}

build_authorization_url <- function(
  base_url,
  client_id,
  redirect_uri,
  code_challenge,
  state,
  scope = ""
) {
  params <- list(
    client_id = client_id,
    response_type = "code",
    redirect_uri = redirect_uri,
    code_challenge = code_challenge,
    code_challenge_method = "S256",
    state = state
  )
  if (nzchar(scope)) {
    params$scope <- scope
  }
  query <- paste0(
    curl::curl_escape(names(params)),
    "=",
    curl::curl_escape(params),
    collapse = "&"
  )
  paste0(base_url, "?", query)
}

request_oauth_tokens <- function(
  token_url,
  grant_type,
  client_id,
  client_secret,
  code = NULL,
  redirect_uri = NULL,
  code_verifier = NULL,
  refresh_token = NULL,
  scope = NULL
) {
  form_data <- list(grant_type = grant_type)
  if (!is.null(code)) form_data$code <- code
  if (!is.null(redirect_uri)) form_data$redirect_uri <- redirect_uri
  if (!is.null(code_verifier)) form_data$code_verifier <- code_verifier
  if (!is.null(refresh_token)) form_data$refresh_token <- refresh_token
  if (!is.null(scope)) form_data$scope <- scope

  body <- formEncode(form_data)
  credentials <- openssl::base64_encode(
    charToRaw(paste0(client_id, ":", client_secret))
  )

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = body)
  curl::handle_setheaders(
    handle,
    `Content-Type` = "application/x-www-form-urlencoded",
    `Accept` = "application/json",
    `Authorization` = paste("Basic", credentials)
  )

  resp <- curl::curl_fetch_memory(token_url, handle)
  if (resp$status_code >= 400) {
    detail <- NULL
    tryCatch(
      {
        content <- jsonlite::fromJSON(
          rawToChar(resp$content),
          simplifyVector = FALSE
        )
        detail <- content$message %||%
          content$error_description %||%
          content$error
      },
      error = function(e) NULL
    )
    cli::cli_abort(
      c(
        "OAuth token request failed with status {resp$status_code}",
        i = detail
      )
    )
  }

  content <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
  if (is.null(content$access_token)) {
    cli::cli_abort("OAuth token response missing access_token")
  }

  list(
    access_token = content$access_token,
    refresh_token = content$refresh_token,
    expires_in = content$expires_in
  )
}

oauth_code_listen <- function(port) {
  code <- NULL
  state <- NULL
  done <- FALSE

  listen <- function(req) {
    if (!identical(req$PATH_INFO, "/") || req$REQUEST_METHOD != "GET") {
      return(
        list(
          status = 404L,
          headers = list("Content-Type" = "text/plain"),
          body = "Not found"
        )
      )
    }

    query <- req$QUERY_STRING
    if (!is.character(query) || !nzchar(query)) {
      done <<- TRUE
      return(
        list(
          status = 400L,
          headers = list("Content-Type" = "text/plain"),
          body = "Missing query parameters"
        )
      )
    }

    parsed <- parse_query_string(query)
    if (!is.null(parsed$error)) {
      done <<- TRUE
      return(
        list(
          status = 400L,
          headers = list("Content-Type" = "text/plain"),
          body = paste(
            "Authorization error:",
            parsed$error_description %||% parsed$error
          )
        )
      )
    }

    code <<- parsed$code
    state <<- parsed$state
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

  if (is.null(code)) {
    cli::cli_abort(
      "local OAuth authentication failed: no authorization code received"
    )
  }

  list(code = code, state = state)
}

parse_query_string <- function(query) {
  query <- sub("^\\?", "", query)
  pairs <- strsplit(query, "&", fixed = TRUE)[[1]]
  result <- list()
  for (pair in pairs) {
    eq_pos <- regexpr("=", pair, fixed = TRUE)
    if (eq_pos > 0) {
      key <- substr(pair, 1, eq_pos - 1)
      value <- substr(pair, eq_pos + 1, nchar(pair))
      result[[curl::curl_unescape(key)]] <- curl::curl_unescape(value)
    }
  }
  result
}
