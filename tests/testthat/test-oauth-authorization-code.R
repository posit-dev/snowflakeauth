test_that("oauth_authorization_code_credentials returns cached session when valid", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL
  )

  mock_session <- list(
    token = "cached_session_token",
    expires_at = as.numeric(Sys.time()) + 3600,
    master_token = "cached_master_token",
    master_expires_at = as.numeric(Sys.time()) + 7200
  )

  mock_cache <- list(
    get = function() mock_session,
    set = function(session) NULL,
    clear = function() NULL
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="cached_session_token"')
  )
})

test_that("cached session works in non-interactive sessions", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL
  )

  mock_session <- list(
    token = "cached_session_token",
    expires_at = as.numeric(Sys.time()) + 3600,
    master_token = "cached_master_token",
    master_expires_at = as.numeric(Sys.time()) + 7200
  )

  mock_cache <- list(
    get = function() mock_session,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() FALSE,
    .package = "rlang"
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="cached_session_token"')
  )
})

test_that("oauth_authorization_code_credentials renews session when expired but master valid", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL
  )

  mock_session <- list(
    token = "expired_session_token",
    expires_at = as.numeric(Sys.time()) - 100,
    master_token = "valid_master_token",
    master_expires_at = as.numeric(Sys.time()) + 3600
  )

  cached_session <- NULL
  mock_cache <- list(
    get = function() mock_session,
    set = function(session) cached_session <<- session,
    clear = function() NULL
  )

  local_mocked_bindings(
    renew_session = function(account, session, host = NULL) {
      list(
        token = "renewed_session_token",
        expires_at = as.numeric(Sys.time()) + 3600,
        master_token = session$master_token,
        master_expires_at = session$master_expires_at
      )
    }
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="renewed_session_token"')
  )
  expect_equal(cached_session$token, "renewed_session_token")
})

test_that("oauth_authorization_code_credentials uses refresh token from keyring", {
  params <- list(
    account = "testaccount",
    user = "testuser",
    host = NULL,
    oauth_client_id = NULL,
    oauth_client_secret = NULL,
    oauth_token_request_url = NULL,
    oauth_scope = NULL,
    role = NULL
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    is_hosted_session = function() FALSE,
    use_keyring = function() TRUE,
    keyring_get_token = function(account, user, token_type) {
      if (token_type == "OAUTH_REFRESH_TOKEN") {
        list(token = "cached_refresh_token", expires_at = Inf)
      } else {
        NULL
      }
    },
    keyring_cache_token = function(
      account,
      user,
      token_type,
      token,
      expires_at
    ) {
      NULL
    },
    request_oauth_tokens = function(token_url, grant_type, ...) {
      expect_equal(grant_type, "refresh_token")
      list(
        access_token = "new_access_token",
        refresh_token = "new_refresh_token",
        expires_in = 600
      )
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list(),
      host = NULL
    ) {
      expect_equal(data$AUTHENTICATOR, "OAUTH")
      expect_equal(data$TOKEN, "new_access_token")
      list(
        token = "session_from_refresh",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="session_from_refresh"')
  )
})

test_that("oauth_authorization_code_credentials clears keyring on refresh failure", {
  params <- list(
    account = "testaccount",
    user = "testuser",
    host = NULL,
    oauth_client_id = NULL,
    oauth_client_secret = NULL,
    oauth_authorization_url = NULL,
    oauth_token_request_url = NULL,
    oauth_scope = NULL,
    role = NULL
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  keyring_cleared <- FALSE
  browser_opened <- FALSE

  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    browseURL = function(url) NULL,
    .package = "utils"
  )
  local_mocked_bindings(
    is_hosted_session = function() FALSE,
    use_keyring = function() TRUE,
    keyring_get_token = function(account, user, token_type) {
      if (token_type == "OAUTH_REFRESH_TOKEN") {
        list(token = "expired_refresh_token", expires_at = Inf)
      } else {
        NULL
      }
    },
    keyring_clear_token = function(account, user, token_type) {
      keyring_cleared <<- TRUE
    },
    keyring_cache_token = function(
      account,
      user,
      token_type,
      token,
      expires_at
    ) {
      NULL
    },
    request_oauth_tokens = function(token_url, grant_type, ...) {
      if (grant_type == "refresh_token") {
        stop("refresh token expired")
      }
      list(
        access_token = "fresh_access_token",
        refresh_token = NULL,
        expires_in = 600
      )
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list(),
      host = NULL
    ) {
      list(
        token = "session_from_browser",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    },
    oauth_code_listen = function(port) {
      browser_opened <<- TRUE
      list(code = "auth_code", state = "test_state")
    },
    generate_pkce = function() {
      list(verifier = "test_verifier", challenge = "test_challenge")
    },
    base64url_encode = function(raw_bytes) "test_state"
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_true(keyring_cleared)
  expect_true(browser_opened)
  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="session_from_browser"')
  )
})

test_that("oauth_authorization_code_credentials does full browser flow", {
  params <- list(
    account = "testaccount",
    user = "testuser",
    host = NULL,
    oauth_client_id = NULL,
    oauth_client_secret = NULL,
    oauth_authorization_url = NULL,
    oauth_token_request_url = NULL,
    oauth_scope = NULL,
    role = NULL
  )

  cached_session <- NULL
  mock_cache <- list(
    get = function() NULL,
    set = function(session) cached_session <<- session,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    browseURL = function(url) NULL,
    .package = "utils"
  )
  local_mocked_bindings(
    is_hosted_session = function() FALSE,
    use_keyring = function() FALSE,
    generate_pkce = function() {
      list(verifier = "test_verifier", challenge = "test_challenge")
    },
    base64url_encode = function(raw_bytes) "test_state",
    oauth_code_listen = function(port) {
      list(code = "auth_code_123", state = "test_state")
    },
    request_oauth_tokens = function(
      token_url,
      grant_type,
      client_id,
      client_secret,
      ...
    ) {
      expect_equal(grant_type, "authorization_code")
      expect_equal(client_id, "LOCAL_APPLICATION")
      expect_equal(client_secret, "LOCAL_APPLICATION")
      args <- list(...)
      expect_equal(args$code, "auth_code_123")
      expect_equal(args$code_verifier, "test_verifier")
      list(
        access_token = "browser_access_token",
        refresh_token = NULL,
        expires_in = 600
      )
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list(),
      host = NULL
    ) {
      expect_equal(data$AUTHENTICATOR, "OAUTH")
      expect_equal(data$TOKEN, "browser_access_token")
      list(
        token = "session_token",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="session_token"')
  )
  expect_equal(cached_session$token, "session_token")
})

test_that("oauth_authorization_code_credentials aborts on state mismatch", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL,
    oauth_client_id = NULL,
    oauth_client_secret = NULL,
    oauth_authorization_url = NULL,
    oauth_token_request_url = NULL,
    oauth_scope = NULL,
    role = NULL
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    browseURL = function(url) NULL,
    .package = "utils"
  )
  local_mocked_bindings(
    is_hosted_session = function() FALSE,
    use_keyring = function() FALSE,
    generate_pkce = function() {
      list(verifier = "test_verifier", challenge = "test_challenge")
    },
    base64url_encode = function(raw_bytes) "expected_state",
    oauth_code_listen = function(port) {
      list(code = "auth_code", state = "wrong_state")
    }
  )

  expect_error(
    oauth_authorization_code_credentials(params, cache = mock_cache),
    "state mismatch"
  )
})

test_that("oauth_authorization_code_credentials aborts in non-interactive session", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL,
    oauth_scope = NULL,
    oauth_token_request_url = NULL,
    role = NULL
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() FALSE,
    .package = "rlang"
  )
  local_mocked_bindings(
    use_keyring = function() FALSE
  )

  expect_error(
    oauth_authorization_code_credentials(params, cache = mock_cache),
    "interactive"
  )
})

test_that("oauth_authorization_code_credentials aborts in hosted session", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL,
    oauth_scope = NULL,
    oauth_token_request_url = NULL,
    role = NULL
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    use_keyring = function() FALSE,
    is_hosted_session = function() TRUE
  )

  expect_error(
    oauth_authorization_code_credentials(params, cache = mock_cache),
    "hosted"
  )
})

test_that("generate_pkce produces valid verifier and challenge", {
  pkce <- generate_pkce()

  expect_type(pkce$verifier, "character")
  expect_type(pkce$challenge, "character")

  # Verifier should be base64url-encoded (no +, /, or =)
  expect_false(grepl("[+/=]", pkce$verifier))
  # Challenge should be base64url-encoded
  expect_false(grepl("[+/=]", pkce$challenge))

  # Challenge should be SHA-256 of verifier, base64url-encoded
  expected_challenge <- base64url_encode(
    openssl::sha256(charToRaw(pkce$verifier))
  )
  expect_equal(pkce$challenge, expected_challenge)
})

test_that("base64url_encode removes padding and replaces characters", {
  # Known input that produces +, /, and = in standard base64
  raw_input <- as.raw(c(0xfb, 0xff, 0xfe))
  result <- base64url_encode(raw_input)

  expect_false(grepl("+", result, fixed = TRUE))
  expect_false(grepl("/", result, fixed = TRUE))
  expect_false(grepl("=", result, fixed = TRUE))
})

test_that("build_authorization_url includes all required params", {
  url <- build_authorization_url(
    "https://account.snowflakecomputing.com/oauth/authorize",
    client_id = "LOCAL_APPLICATION",
    redirect_uri = "http://127.0.0.1:8080",
    code_challenge = "challenge123",
    state = "state456",
    scope = "session:role:ANALYST"
  )

  expect_match(
    url,
    "^https://account.snowflakecomputing.com/oauth/authorize\\?"
  )
  expect_match(url, "client_id=LOCAL_APPLICATION")
  expect_match(url, "response_type=code")
  expect_match(url, "redirect_uri=http")
  expect_match(url, "code_challenge=challenge123")
  expect_match(url, "code_challenge_method=S256")
  expect_match(url, "state=state456")
  expect_match(url, "scope=session")
})

test_that("build_authorization_url omits scope when empty", {
  url <- build_authorization_url(
    "https://account.snowflakecomputing.com/oauth/authorize",
    client_id = "LOCAL_APPLICATION",
    redirect_uri = "http://127.0.0.1:8080",
    code_challenge = "challenge123",
    state = "state456",
    scope = ""
  )

  expect_no_match(url, "scope=")
})

test_that("scope auto-populates with role when scope is empty", {
  params <- list(
    account = "testaccount",
    user = NULL,
    host = NULL,
    oauth_client_id = NULL,
    oauth_client_secret = NULL,
    oauth_authorization_url = NULL,
    oauth_token_request_url = NULL,
    oauth_scope = NULL,
    role = "ANALYST"
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  captured_url <- NULL
  local_mocked_bindings(
    is_interactive = function() TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    browseURL = function(url) captured_url <<- url,
    .package = "utils"
  )
  local_mocked_bindings(
    is_hosted_session = function() FALSE,
    use_keyring = function() FALSE,
    generate_pkce = function() {
      list(verifier = "v", challenge = "c")
    },
    base64url_encode = function(raw_bytes) "state",
    oauth_code_listen = function(port) {
      list(code = "code", state = "state")
    },
    request_oauth_tokens = function(token_url, grant_type, ...) {
      args <- list(...)
      list(access_token = "tok", refresh_token = NULL, expires_in = 600)
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list(),
      host = NULL
    ) {
      list(token = "session", expires_at = as.numeric(Sys.time()) + 3600)
    }
  )

  oauth_authorization_code_credentials(params, cache = mock_cache)

  expect_match(captured_url, "session%3Arole%3AANALYST")
})

test_that("parse_query_string correctly parses query parameters", {
  result <- parse_query_string("?code=abc123&state=xyz789")
  expect_equal(result$code, "abc123")
  expect_equal(result$state, "xyz789")

  result2 <- parse_query_string("code=hello%20world&other=value")
  expect_equal(result2$code, "hello world")
  expect_equal(result2$other, "value")
})

test_that("parse_query_string handles = in values", {
  result <- parse_query_string("code=abc%3Ddef&state=xyz")
  expect_equal(result$code, "abc=def")
  expect_equal(result$state, "xyz")

  result2 <- parse_query_string("code=a=b=c&state=ok")
  expect_equal(result2$code, "a=b=c")
  expect_equal(result2$state, "ok")
})

test_that("build_scope includes refresh_token by default", {
  expect_equal(build_scope(), "refresh_token")
  expect_equal(
    build_scope(role = "ANALYST"),
    "session:role:ANALYST refresh_token"
  )
  expect_equal(
    build_scope(oauth_scope = "session:role:ADMIN"),
    "session:role:ADMIN refresh_token"
  )
})

test_that("build_scope does not duplicate refresh_token", {
  expect_equal(
    build_scope(oauth_scope = "refresh_token"),
    "refresh_token"
  )
  expect_equal(
    build_scope(oauth_scope = "session:role:ADMIN refresh_token"),
    "session:role:ADMIN refresh_token"
  )
})

test_that("build_scope uses exact token matching for refresh_token", {
  result <- build_scope(oauth_scope = "session:role:team_refresh_token_ops")
  expect_equal(
    result,
    "session:role:team_refresh_token_ops refresh_token"
  )
})

test_that("config normalizes OAUTH_AUTHORIZATION_CODE to lowercase", {
  conn <- snowflake_connection(
    name = "oauth_auth_code_uppercase",
    .config_dir = test_path()
  )
  expect_equal(conn$authenticator, "oauth_authorization_code")
})

test_that("config accepts oauth_authorization_code without user", {
  conn <- snowflake_connection(
    name = "oauth_auth_code",
    .config_dir = test_path()
  )
  expect_equal(conn$authenticator, "oauth_authorization_code")
  expect_null(conn$user)
})
