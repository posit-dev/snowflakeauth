test_that("JWT generation works as expected", {
  skip_if_not_installed("jose")

  # Verify deterministic JWTs.
  jwt <- generate_jwt(
    "account",
    "user",
    test_path("test_rsa_key1.p8"),
    iat = 1730393963,
    jti = "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
  )
  expect_snapshot(jose::jwt_split(jwt))

  # Verify non-deterministic JWTs by checking against the wrong public key.
  jwt <- generate_jwt("account", "user", test_path("test_rsa_key1.p8"))
  expect_error(
    jose::jwt_decode_sig(jwt, test_path("test_rsa_key2.pub")),
    regexp = "incorrect signature"
  )
})

test_that("exchange_jwt_for_token works as expected", {
  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        status_code = 200,
        content = charToRaw("test_access_token")
      )
    },
    .package = "curl"
  )

  token <- exchange_jwt_for_token(
    "https://testaccount.snowflakecomputing.com",
    "test_jwt",
    "test.endpoint.com",
    "PUBLIC"
  )

  expect_equal(token$access_token, "test_access_token")
  expect_equal(token$expires_in, 300L)
})

test_that("exchange_jwt_for_token handles errors correctly", {
  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        status_code = 401,
        content = charToRaw("Unauthorized")
      )
    },
    .package = "curl"
  )

  expect_snapshot(
    exchange_jwt_for_token(
      "https://testaccount.snowflakecomputing.com",
      "test_jwt",
      "test.endpoint.com"
    ),
    error = TRUE
  )
})
