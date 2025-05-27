test_that("default_config_dir finds config directories correctly", {
  withr::local_envvar(
    c(
      SNOWFLAKE_HOME = NA,
      XDG_CONFIG_HOME = test_path(".")
    )
  )

  expect_equal(
    default_config_dir(),
    file.path(test_path("."), "snowflake")
  )
})

test_that("SNOWFLAKE_HOME environment variable is respected", {
  withr::with_envvar(
    c(SNOWFLAKE_HOME = test_path(".")),
    expect_equal(
      snowflake_connection("test1")[["authenticator"]],
      "oauth"
    )
  )
})

test_that("generic environment variables are respected", {
  withr::with_envvar(
    c(
      SNOWFLAKE_ACCOUNT = "env_account",
      SNOWFLAKE_USER = "env_user",
      SNOWFLAKE_PASSWORD = "env_password",
      SNOWFLAKE_AUTHENTICATOR = "env_authenticator"
    ),
    expect_equal(
      snowflake_connection(.config_dir = tempdir())[["account"]],
      "env_account"
    )
  )
})

test_that("user-provided connection params win over config.toml file params", {
  config_dir <- tempdir()
  withr::local_file(file.path(config_dir, "config.toml"))
  writeLines(
    c(
      'default_connection_name = "test1"',
      '[connections.test1]',
      'account = "testorg-test_account"',
      'user = "user"',
      'password = "password"',
      'role = "role"',
      'authenticator = "externalbrowser"'
    ),
    file.path(config_dir, "config.toml")
  )

  conn <- snowflake_connection(
    account = "override_account",
    user = "override_user",
    role = "override_role",
    authenticator = "override_authenticator",
    .config_dir = config_dir
  )
  expect_equal(conn[["account"]], "override_account")
  expect_equal(conn[["user"]], "override_user")
  expect_equal(conn[["role"]], "override_role")
})

test_that("user-provided connection params win over generic environment variables", {
  withr::local_envvar(
    c(
      SNOWFLAKE_ACCOUNT = "env_account",
      SNOWFLAKE_USER = "env_user"
    )
  )

  conn <- snowflake_connection(user = "override_user", .config_dir = tempdir())
  expect_equal(conn[["account"]], "env_account")
  expect_equal(conn[["user"]], "override_user")
})

test_that("SNOWFLAKE_CONNECTIONS_* win over config.toml params", {
  config_dir <- tempdir()
  withr::local_file(file.path(config_dir, "config.toml"))
  writeLines(
    c(
      'default_connection_name = "test1"',
      '[connections.test1]',
      'account = "testorg-test_account"',
      'role = "role"'
    ),
    file.path(config_dir, "config.toml")
  )

  withr::local_envvar(
    c(SNOWFLAKE_CONNECTIONS_test1_ROLE = "env_role")
  )
  conn <- snowflake_connection(.config_dir = config_dir)
  expect_equal(conn[["role"]], "env_role")
  expect_equal(conn[["account"]], "testorg-test_account")
})


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

test_that("connections.toml wins if present with config.toml", {
  config_dir <- tempdir()

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

  withr::local_file(file.path(config_dir, "config.toml"))
  writeLines(
    'default_connection_name = "secondary"',
    file.path(config_dir, "config.toml")
  )
  expect_equal(
    snowflake_connection(.config_dir = config_dir)[["account"]],
    "secondary-test-account"
  )
  expect_snapshot(
    snowflake_connection(.config_dir = config_dir),
    transform = function(x) {
      gsub("'/[^']+/([^/']+)'", "'\\1'", x)
    }
  )
})

test_that("conflicting config.toml and connections.toml produce an error", {
  config_dir <- tempdir()

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

  withr::local_file(file.path(config_dir, "config.toml"))
  writeLines(
    'default_connection_name = "test1"',
    file.path(config_dir, "config.toml")
  )
  expect_error(snowflake_connection(.config_dir = config_dir))
})

test_that("SNOWFLAKE_DEFAULT_CONNECTION_NAME wins if set", {
  # Test that the SNOWFLAKE_DEFAULT_CONNECTION_NAME environment variable is respected.
  withr::with_envvar(
    c(SNOWFLAKE_DEFAULT_CONNECTION_NAME = "test2"),
    expect_equal(
      snowflake_connection(.config_dir = test_path("."))[["account"]],
      "testorg-test_account2"
    )
  )
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

  expect_snapshot(
    snowflake_connection(),
    transform = function(x) {
      gsub("'/[^']+/([^/']+)'", "'\\1'", x)
    }
  )
})

test_that("ambient credentials are detected correctly", {
  expect_true(has_a_default_connection("test1", .config_dir = test_path(".")))
  config_dir <- tempfile("snowflake")
  expect_false(has_a_default_connection("test1", .config_dir = config_dir))
})
