test_that("oauth_credentials returns correct headers without spcs_endpoint", {
  token <- "test_token"

  headers <- oauth_credentials("testaccount", token)

  expect_equal(
    headers,
    list(
      Authorization = paste("Bearer", token),
      `X-Snowflake-Authorization-Token-Type` = "OAUTH"
    )
  )
})

test_that("oauth_credentials reads token from file", {
  token <- "test_token_from_file"
  token_file <- tempfile()
  withr::local_file(token_file)
  writeLines(token, token_file)

  headers <- oauth_credentials("testaccount", token_file = token_file)

  expect_equal(
    headers,
    list(
      Authorization = paste("Bearer", token),
      `X-Snowflake-Authorization-Token-Type` = "OAUTH"
    )
  )
})

test_that("oauth_credentials with spcs_endpoint exchanges token", {
  local_mocked_bindings(
    exchange_oauth_token = function(account_url, token, spcs_endpoint) {
      list(token = "exchanged_session_token")
    }
  )

  headers <- oauth_credentials(
    "testaccount",
    "test_token",
    spcs_endpoint = "https://test.endpoint.com"
  )

  expect_equal(
    headers,
    list(
      Authorization = 'Snowflake Token="exchanged_session_token"'
    )
  )
})


test_that("exchange_oauth_token works as expected", {
  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        status_code = 200,
        content = charToRaw('{"data": {"token": "session_token_value"}}')
      )
    },
    .package = "curl"
  )

  token <- exchange_oauth_token(
    "https://testaccount.snowflakecomputing.com",
    "test_token",
    "test.endpoint.com"
  )

  expect_equal(token$token, "session_token_value")
})

test_that("exchange_oauth_token handles errors correctly", {
  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        status_code = 401,
        content = charToRaw('{"error": "Unauthorized"}')
      )
    },
    .package = "curl"
  )

  expect_error(
    exchange_oauth_token(
      "https://testaccount.snowflakecomputing.com",
      "test_token",
      "test.endpoint.com"
    ),
    "Could not exchange OAuth token"
  )
})

test_that("exchange_oauth_token handles missing token in response", {
  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        status_code = 200,
        content = charToRaw('{"data": {"message": "No token provided"}}')
      )
    },
    .package = "curl"
  )

  expect_snapshot(
    exchange_oauth_token(
      "https://testaccount.snowflakecomputing.com",
      "test_token",
      "test.endpoint.com"
    ),
    error = TRUE
  )
})
