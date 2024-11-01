test_that("the default connection name is detected correctly", {
  config_dir <- tempfile("snowflake")
  on.exit(file.remove(file.path(config_dir, "config.toml"), config_dir))
  # No configuration:
  expect_equal(default_connection_name(config_dir), "default")
  # Configuration via file:
  dir.create(config_dir)
  writeLines(
    'default_connection_name = "test1"',
    file.path(config_dir, "config.toml")
  )
  expect_equal(default_connection_name(config_dir), "test1")
  # Configuration via environment variable takes precedence:
  withr::local_envvar(
    SNOWFLAKE_DEFAULT_CONNECTION_NAME = "test2"
  )
  expect_equal(default_connection_name(config_dir), "test2")
})

# TODO: Test the SNOWFLAKE_HOME logic.

test_that("the connections.toml file is parsed correctly", {
  dir <- test_path(".")
  expect_snapshot(snowflake_connection("test1", .config_dir = dir))
  expect_snapshot(snowflake_connection("test2", .config_dir = dir))
  expect_snapshot(snowflake_connection("test3", .config_dir = dir))
  expect_snapshot(snowflake_connection("test4", .config_dir = dir))
  expect_snapshot(
    snowflake_connection("test5", .config_dir = dir),
    error = TRUE
  )
  # There is no default, so omitting `name` is an error.
  expect_snapshot(snowflake_connection(.config_dir = dir), error = TRUE)
  # Test overriding a parameter:
  expect_snapshot(snowflake_connection(
    "test3",
    private_key_file = "file",
    schema = "schema",
    warehouse = "warehouse",
    .config_dir = dir
  ))
})

test_that("connections can be created without a connections.toml file", {
  expect_snapshot(snowflake_connection(.config_dir = "/test"), error = TRUE)
  expect_snapshot(snowflake_connection(
    account = "testorg-test_account",
    user = "user",
    role = "role",
    authenticator = "externalbrowser",
    .config_dir = "/test"
  ))
})

test_that("Workbench-managed credentials are detected correctly", {
  # Emulate the config.toml and connections.toml files written by Workbench.
  config_dir <- tempfile("posit-workbench")
  cfg <- file.path(config_dir, "config.toml")
  connections <- file.path(config_dir, "connections.toml")
  on.exit(file.remove(cfg, connections, config_dir))
  dir.create(config_dir)
  writeLines('default_connection_name = "workbench"', cfg)
  writeLines(
    c(
      '[workbench]',
      'account = "testorg-test_account"',
      'token = "token"',
      'authenticator = "oauth"'
    ),
    connections
  )
  withr::local_envvar(
    SNOWFLAKE_ACCOUNT = "testorg-test_account",
    SNOWFLAKE_HOME = config_dir
  )
  expect_snapshot(snowflake_connection())
})
