test_that("workload_identity_credentials rejects non-OIDC providers", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "UNSUPPORTED"
  )

  expect_snapshot(
    workload_identity_credentials(params),
    error = TRUE
  )
})

test_that("workload_identity_credentials returns cached session when valid", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "OIDC"
  )

  # Create a mock cache with a valid session

  mock_session <- list(
    token = "cached_session_token",
    expires_at = as.numeric(Sys.time()) + 3600, # Valid for 1 hour
    master_token = "cached_master_token",
    master_expires_at = as.numeric(Sys.time()) + 7200
  )

  mock_cache <- list(
    get = function() mock_session,
    set = function(session) NULL,
    clear = function() NULL
  )

  result <- workload_identity_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="cached_session_token"')
  )
})

test_that("workload_identity_credentials renews session when expired but master valid", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "OIDC"
  )

  # Create a mock cache with an expired session but valid master token
  mock_session <- list(
    token = "expired_session_token",
    expires_at = as.numeric(Sys.time()) - 100, # Expired
    master_token = "valid_master_token",
    master_expires_at = as.numeric(Sys.time()) + 3600 # Still valid
  )

  cached_session <- NULL
  mock_cache <- list(
    get = function() mock_session,
    set = function(session) cached_session <<- session,
    clear = function() NULL
  )

  local_mocked_bindings(
    renew_session = function(account, session) {
      list(
        token = "renewed_session_token",
        expires_at = as.numeric(Sys.time()) + 3600,
        master_token = session$master_token,
        master_expires_at = session$master_expires_at
      )
    }
  )

  result <- workload_identity_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="renewed_session_token"')
  )
  expect_equal(cached_session$token, "renewed_session_token")
})

test_that("workload_identity_credentials falls back to fresh auth when renewal fails", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "OIDC"
  )

  # Create a mock cache with an expired session but valid master token
  mock_session <- list(
    token = "expired_session_token",
    expires_at = as.numeric(Sys.time()) - 100, # Expired
    master_token = "valid_master_token",
    master_expires_at = as.numeric(Sys.time()) + 3600 # Still valid
  )

  cached_session <- NULL
  mock_cache <- list(
    get = function() mock_session,
    set = function(session) cached_session <<- session,
    clear = function() NULL
  )

  local_mocked_bindings(
    renew_session = function(account, session) {
      stop("Renewal failed")
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list()
    ) {
      list(
        token = "fresh_session_token",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- workload_identity_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="fresh_session_token"')
  )
  expect_equal(cached_session$token, "fresh_session_token")
})

test_that("workload_identity_credentials does fresh auth when no cache", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "OIDC"
  )

  cached_session <- NULL
  mock_cache <- list(
    get = function() NULL,
    set = function(session) cached_session <<- session,
    clear = function() NULL
  )

  local_mocked_bindings(
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list()
    ) {
      expect_equal(data$AUTHENTICATOR, "WORKLOAD_IDENTITY")
      expect_equal(data$PROVIDER, "OIDC")
      expect_equal(data$TOKEN, "test_token")
      list(
        token = "new_session_token",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- workload_identity_credentials(params, cache = mock_cache)

  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="new_session_token"')
  )
  expect_equal(cached_session$token, "new_session_token")
})

test_that("workload_identity_credentials skips renewal when master token expired", {
  params <- list(
    account = "testaccount",
    token = "test_token",
    workload_identity_provider = "OIDC"
  )

  # Both session and master tokens are expired
  mock_session <- list(
    token = "expired_session_token",
    expires_at = as.numeric(Sys.time()) - 100,
    master_token = "expired_master_token",
    master_expires_at = as.numeric(Sys.time()) - 50
  )

  renewal_called <- FALSE
  mock_cache <- list(
    get = function() mock_session,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    renew_session = function(account, session) {
      renewal_called <<- TRUE
      stop("Should not be called")
    },
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list()
    ) {
      list(
        token = "fresh_session_token",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- workload_identity_credentials(params, cache = mock_cache)

  expect_false(renewal_called)
  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="fresh_session_token"')
  )
})

test_that("workload_identity_credentials prefers token_file_path over inline token", {
  token_file <- withr::local_tempfile()
  # Note: use cat() to avoid writing a trailing newline.
  cat("file_token", file = token_file)

  params <- list(
    account = "testaccount",
    token = "inline_token",
    token_file_path = token_file,
    workload_identity_provider = "OIDC"
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  local_mocked_bindings(
    login_request = function(
      account,
      data,
      user = NULL,
      extra_headers = list()
    ) {
      expect_equal(data$TOKEN, "file_token")
      list(
        token = "session_token",
        expires_at = as.numeric(Sys.time()) + 3600
      )
    }
  )

  result <- workload_identity_credentials(params, cache = mock_cache)
  expect_equal(
    result,
    list(Authorization = 'Snowflake Token="session_token"')
  )
})

test_that("workload_identity_credentials rejects empty token file", {
  token_file <- withr::local_tempfile()
  file.create(token_file) # Create empty file

  params <- list(
    account = "testaccount",
    token_file_path = token_file,
    workload_identity_provider = "OIDC"
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  expect_error(
    workload_identity_credentials(params, cache = mock_cache),
    "is empty"
  )
})

test_that("workload_identity_credentials errors on non-existent token file", {
  params <- list(
    account = "testaccount",
    token_file_path = "/nonexistent/path/to/token",
    workload_identity_provider = "OIDC"
  )

  mock_cache <- list(
    get = function() NULL,
    set = function(session) NULL,
    clear = function() NULL
  )

  expect_error(
    workload_identity_credentials(params, cache = mock_cache),
    "Failed to read token"
  )
})
