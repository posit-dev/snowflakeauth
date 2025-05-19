test_that("the configuration precedence hierarchy is resolved correctly", {
  config_dir <- tempdir()

  cfg <- load_snowflake_config(config_dir = config_dir)
  expect_null(cfg[["connections"]])

  ## add connections.toml
  withr::local_file(config_dir, "connections.toml")
  writeLines(
    c(
      '[default]',
      'account = "testorg-test-account"',
      'user = "user"',
      'role = "role"',
      '[secondary]',
      'account = "secondary-test-account"',
      'user = "user"',
      'role = "role"'
    ),
    file.path(config_dir, "connections.toml")
  )
  # check that connections info comes from connections.toml
  cfg <- load_snowflake_config(config_dir = config_dir)
  expect_equal(cfg[["connection_name"]], "default")
  expect_equal(
    cfg[["connections"]][["default"]][["account"]],
    "testorg-test-account"
  )

  # via environment variable takes precedence:
  withr::with_envvar(
    c(SNOWFLAKE_DEFAULT_CONNECTION_NAME = "secondary"),
    expect_equal(
      load_snowflake_config(config_dir = config_dir)[["connection_name"]],
      "secondary"
    )
  )

  withr::local_file(file.path(config_dir, "config.toml"))
  writeLines(
    'default_connection_name = "test1"',
    file.path(config_dir, "config.toml")
  )
  expect_error(load_snowflake_config(config_dir = config_dir))
})

# TODO: Test the SNOWFLAKE_HOME logic.

test_that("the connections.toml file is parsed correctly", {
  dir <- test_path(".")
  expect_snapshot(snowflake_connection("test1", .config_dir = dir))
  expect_snapshot(snowflake_connection("test2", .config_dir = dir))
  expect_snapshot(snowflake_connection("test3", .config_dir = dir))
  expect_snapshot(snowflake_connection("test4", .config_dir = dir))
  expect_snapshot(snowflake_connection("test6", .config_dir = dir))
  expect_snapshot(
    snowflake_connection("test5", .config_dir = dir),
    error = TRUE
  )
  expect_snapshot(
    snowflake_connection("test7", .config_dir = dir),
    error = TRUE
  )
  expect_snapshot(
    snowflake_connection("test8", .config_dir = dir),
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

test_that("ambient credentials are detected correctly", {
  expect_true(has_a_default_connection("test1", .config_dir = test_path(".")))
  config_dir <- tempfile("snowflake")
  expect_false(has_a_default_connection("test1", .config_dir = config_dir))
})
