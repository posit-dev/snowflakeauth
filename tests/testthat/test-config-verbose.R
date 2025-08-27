test_that("verbose mode logs configuration loading steps", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      'default_connection_name = "test1"',
      "[connections.test1]",
      'account = "testorg-test_account"',
      'user = "user"',
      'role = "role"',
      'authenticator = "externalbrowser"'
    ),
    cfg
  )

  # Test verbose output with config.toml
  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Loading Snowflake configuration from"
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Found config.toml at"
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Using default_connection_name from config.toml"
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Using connection name: \"test1\""
  )

  # Test that verbose = FALSE produces no messages
  expect_silent(
    snowflake_connection(.config_dir = config_dir, .verbose = FALSE)
  )
})

test_that("verbose mode logs environment variable usage", {
  config_dir <- withr::local_tempdir()

  withr::local_envvar(
    c(
      SNOWFLAKE_ACCOUNT = "env_account",
      SNOWFLAKE_USER = "env_user",
      SNOWFLAKE_DEFAULT_CONNECTION_NAME = "env_connection"
    )
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Using connection name from SNOWFLAKE_DEFAULT_CONNECTION_NAME"
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Found environment variables for connection"
  )

  # This test needs to not have a connection name to trigger the "Creating default" message
  withr::local_envvar(
    c(
      SNOWFLAKE_ACCOUNT = "env_account",
      SNOWFLAKE_USER = "env_user",
      SNOWFLAKE_DEFAULT_CONNECTION_NAME = NA
    )
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Applying environment variables for default connection"
  )
})

test_that("verbose mode logs connection-specific environment variables", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      'default_connection_name = "prod"',
      "[connections.prod]",
      'account = "testorg-test_account"'
    ),
    cfg
  )

  withr::local_envvar(
    c(
      SNOWFLAKE_CONNECTIONS_prod_USER = "prod_user",
      SNOWFLAKE_CONNECTIONS_prod_ROLE = "prod_role"
    )
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Applying environment variables for \"prod\""
  )
})

test_that("verbose mode logs when no configuration files are found", {
  config_dir <- withr::local_tempdir()

  withr::local_envvar(
    c(SNOWFLAKE_ACCOUNT = "test_account")
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "No configuration files found in"
  )
})

test_that("verbose mode logs named connection parameter", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      "[connections.custom]",
      'account = "custom-account"',
      'user = "custom-user"'
    ),
    cfg
  )

  expect_message(
    snowflake_connection(
      name = "custom",
      .config_dir = config_dir,
      .verbose = TRUE
    ),
    "Using connection name from parameter: \"custom\""
  )
})

test_that("verbose mode logs generic environment variables", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      "[connections.test1]",
      'account = "test-account"'
    ),
    cfg
  )

  withr::local_envvar(
    c(
      SNOWFLAKE_DEFAULT_CONNECTION_NAME = "test1",
      SNOWFLAKE_USER = "env_user",
      SNOWFLAKE_ROLE = "env_role"
    )
  )

  expect_message(
    snowflake_connection(.config_dir = config_dir, .verbose = TRUE),
    "Applied environment variables"
  )
})
