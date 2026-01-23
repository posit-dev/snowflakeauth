test_that("keyring_service matches the Python format", {
  expect_equal(
    keyring_service("myaccount", "john.doe", "ID_TOKEN"),
    "MYACCOUNT.SNOWFLAKECOMPUTING.COM:JOHN.DOE:ID_TOKEN"
  )
  expect_equal(
    keyring_service("myaccount.us-east-1", "user@example.com", "ID_TOKEN"),
    "MYACCOUNT.US-EAST-1.SNOWFLAKECOMPUTING.COM:USER@EXAMPLE.COM:ID_TOKEN"
  )
  expect_equal(
    keyring_service("myaccount.snowflakecomputing.com", "john.doe", "ID_TOKEN"),
    "MYACCOUNT.SNOWFLAKECOMPUTING.COM:JOHN.DOE:ID_TOKEN"
  )
  expect_equal(
    keyring_service(
      "myaccount.us-east-1.snowflakecomputing.com",
      "john.doe",
      "ID_TOKEN"
    ),
    "MYACCOUNT.US-EAST-1.SNOWFLAKECOMPUTING.COM:JOHN.DOE:ID_TOKEN"
  )
  expect_equal(
    keyring_service("MyAccount", "John.Doe", "ID_TOKEN"),
    "MYACCOUNT.SNOWFLAKECOMPUTING.COM:JOHN.DOE:ID_TOKEN"
  )
  expect_equal(
    keyring_service("myaccount", "john.doe", "MFA_TOKEN"),
    "MYACCOUNT.SNOWFLAKECOMPUTING.COM:JOHN.DOE:MFA_TOKEN"
  )
})

test_that("keyring_get_token returns NULL when no token cached", {
  skip_if_not_installed("keyring")
  withr::local_options(keyring_backend = "env")

  result <- keyring_get_token(
    "nonexistent-test-account-12345",
    "nonexistent-user",
    "ID_TOKEN"
  )
  expect_null(result)
})

test_that("keyring_cache_token and keyring_get_token roundtrip", {
  skip_if_not_installed("keyring")
  withr::local_options(keyring_backend = "env")

  account <- "test-account"
  user <- "test-user"
  token_type <- "ID_TOKEN"
  token <- "test-token-value"
  expires_at <- as.numeric(Sys.time()) + 3600

  # Cache the token.
  keyring_cache_token(account, user, token_type, token, expires_at)

  # Retrieve it.
  cached <- keyring_get_token(account, user, token_type)
  expect_equal(cached, list(token = token, expires_at = expires_at))

  # Clear it.
  keyring_clear_token(account, user, token_type)

  # Should no longer be cached.
  expect_null(keyring_get_token(account, user, token_type))
})

test_that("keyring_get_token returns NULL for expired tokens", {
  withr::local_options(keyring_backend = "env")

  account <- "test-account-expired"
  user <- "test-user"
  token_type <- "ID_TOKEN"
  token <- "expired-token-value"
  expires_at <- as.numeric(Sys.time()) - 3600 # Expired 1 hour ago

  keyring_cache_token(account, user, token_type, token, expires_at)
  expect_null(keyring_get_token(account, user, token_type))
})
