test_that("JWT generation works as expected", {
  skip_if_not_installed("jose")

  # Verify deterministic JWTs.
  jwt <- generate_jwt(
    "account",
    "user",
    # Generated with:
    # openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out unencrypted_rsa_key.p8 -nocrypt
    # https://docs.snowflake.com/en/user-guide/key-pair-auth#generate-the-private-key
    test_path("unencrypted_rsa_key.p8"),
    iat = 1730393963,
    jti = "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
  )
  expect_snapshot(jose::jwt_split(jwt))

  # Verify non-deterministic JWTs by checking against the wrong public key.
  jwt <- generate_jwt("account", "user", test_path("unencrypted_rsa_key.p8"))
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

test_that("JWT generation works with encrypted private key and passphrase", {
  jwt <- generate_jwt(
    "account",
    "user",
    # Generated with:
    # openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 des3 -inform PEM -out encrypted rsa_key.p8
    # https://docs.snowflake.com/en/user-guide/key-pair-auth#generate-the-private-key
    test_path("encrypted_rsa_key.p8"),
    private_key_pwd = "password",
    iat = 1730393963,
    jti = "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
  )

  expect_type(jwt, "character")

  jwt_parts <- jose::jwt_split(jwt)
  expect_equal(jwt_parts$header$alg, "RS256")
  expect_equal(jwt_parts$payload$sub, "ACCOUNT.USER")
})

test_that("keypair_credentials works with encrypted private key", {
  creds <- keypair_credentials(
    "testaccount",
    "testuser",
    test_path("encrypted_rsa_key.p8"),
    private_key_pwd = "password"
  )

  expect_type(creds, "list")
  expect_true("Authorization" %in% names(creds))
  expect_match(creds$Authorization, "^Bearer ")
  expect_equal(creds$`X-Snowflake-Authorization-Token-Type`, "KEYPAIR_JWT")
})

test_that("keypair_credentials uses host for SPCS exchange when provided", {
  observed_url <- NULL
  local_mocked_bindings(
    exchange_jwt_for_token = function(account_url, jwt, spcs_endpoint, role) {
      observed_url <<- account_url
      list(access_token = "test_token")
    }
  )

  keypair_credentials(
    "testaccount",
    "testuser",
    test_path("unencrypted_rsa_key.p8"),
    spcs_endpoint = "test.endpoint.com",
    host = "myhost.example.com"
  )
  expect_equal(observed_url, "https://myhost.example.com")
})

test_that("JWT generation normalises account identifiers", {
  skip_if_not_installed("jose")

  subject_for <- function(account) {
    jwt <- generate_jwt(
      account,
      "user",
      test_path("unencrypted_rsa_key.p8"),
      iat = 1730393963,
      jti = "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
    )
    jose::jwt_split(jwt)$payload$sub
  }

  expect_equal(subject_for("myaccount"), "MYACCOUNT.USER")
  expect_equal(subject_for("myaccount.us-east-1.aws"), "MYACCOUNT.USER")
  expect_equal(subject_for("myaccount.us-east-1.privatelink"), "MYACCOUNT.USER")
  expect_equal(subject_for("myorg-myaccount.global"), "MYORG.USER")
})
