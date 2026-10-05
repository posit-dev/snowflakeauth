test_that("pat_credentials returns the expected headers", {
  expect_equal(
    pat_credentials("test_pat"),
    list(
      Authorization = "Bearer test_pat",
      `X-Snowflake-Authorization-Token-Type` = "PROGRAMMATIC_ACCESS_TOKEN"
    )
  )
})

test_that("snowflake_connection accepts the PAT authenticator", {
  conn <- snowflake_connection(
    account = "testaccount",
    token = "test_pat",
    authenticator = "programmatic_access_token"
  )

  expect_equal(conn$authenticator, "PROGRAMMATIC_ACCESS_TOKEN")
  expect_s3_class(conn, "snowflake_connection")
})

test_that("PAT authentication requires a token", {
  expect_error(
    snowflake_connection(
      account = "testaccount",
      authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
    ),
    "One of `token` or `token_file_path` is required when using PROGRAMMATIC_ACCESS_TOKEN authentication"
  )
})

test_that("PAT authentication rejects an empty inline token", {
  expect_error(
    snowflake_connection(
      account = "testaccount",
      token = "",
      authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
    ),
    "One of `token` or `token_file_path` is required when using PROGRAMMATIC_ACCESS_TOKEN authentication"
  )
})

test_that("PAT authentication rejects missing token values", {
  expect_error(
    snowflake_connection(
      account = "testaccount",
      token = NA_character_,
      authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
    ),
    "One of `token` or `token_file_path` is required when using PROGRAMMATIC_ACCESS_TOKEN authentication"
  )

  expect_error(
    snowflake_connection(
      account = "testaccount",
      token_file_path = NA_character_,
      authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
    ),
    "One of `token` or `token_file_path` is required when using PROGRAMMATIC_ACCESS_TOKEN authentication"
  )
})

test_that("PAT authentication reads a token from token_file_path", {
  token_file <- withr::local_tempfile()
  writeLines("test_pat_from_file", token_file)

  conn <- snowflake_connection(
    account = "testaccount",
    token_file_path = token_file,
    authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
  )

  expect_equal(
    snowflake_credentials(conn),
    list(
      Authorization = "Bearer test_pat_from_file",
      `X-Snowflake-Authorization-Token-Type` = "PROGRAMMATIC_ACCESS_TOKEN"
    )
  )
})

test_that("PAT authentication rejects an empty token file", {
  token_file <- withr::local_tempfile()
  file.create(token_file)

  conn <- snowflake_connection(
    account = "testaccount",
    token_file_path = token_file,
    authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
  )

  expect_error(
    snowflake_credentials(conn),
    "PAT token file .* must contain exactly one non-empty line"
  )
})

test_that("PAT authentication rejects a multi-line token file", {
  token_file <- withr::local_tempfile()
  writeLines(c("test_pat_line_one", "test_pat_line_two"), token_file)

  conn <- snowflake_connection(
    account = "testaccount",
    token_file_path = token_file,
    authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
  )

  expect_error(
    snowflake_credentials(conn),
    "PAT token file .* must contain exactly one non-empty line"
  )
})

test_that("snowflake_credentials dispatches PAT authentication", {
  conn <- snowflake_connection(
    account = "testaccount",
    token = "test_pat",
    authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
  )

  expect_equal(
    snowflake_credentials(conn, spcs_endpoint = "https://test.endpoint.com"),
    list(
      Authorization = "Bearer test_pat",
      `X-Snowflake-Authorization-Token-Type` = "PROGRAMMATIC_ACCESS_TOKEN"
    )
  )
})
