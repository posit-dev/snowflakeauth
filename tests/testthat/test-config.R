quoted_path_transformer <- function(x) {
  x <- gsub("'/[^']+/([^/']+)'", "'/CONFIG_DIR/\\1'", x)
  gsub("'[a-zA-Z]:[/\\][^']+[/\\]([^/\\']+)'", "'/CONFIG_DIR/\\1'", x)
}

test_that("quoted path transformer", {
  unix <- "Pass `account` or define a [] section with an account field in '/var/folders/f5/d_lvj8s17bx46zzhfr5gqywc0000gp/T//RtmpvFAajX/filec8d513d8d21/connections.toml'."
  windows <- "Pass `account` or define a [] section with an account field in 'C:\\Users\\RUNNER~1\\AppData\\Local\\Temp\\RtmpeCBJA9/working_dir\\RtmpYn26aW\\file1e60da83468/connections.toml'."
  expected <- "Pass `account` or define a [] section with an account field in '/CONFIG_DIR/connections.toml'."

  expect_equal(
    quoted_path_transformer(unix),
    expected
  )

  expect_equal(
    quoted_path_transformer(windows),
    expected
  )
})

test_that("default_config_dir finds config directories correctly", {
  dir <- withr::local_tempdir()

  # Redefine HOME to be a path that does not exist in case the user running
  # these tests has $HOME/.snowflake
  home <- file.path(dir, "home")

  withr::local_envvar(
    c(
      HOME = home,
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
  withr::local_envvar(
    c(SNOWFLAKE_HOME = test_path("."))
  )

  expect_equal(
    snowflake_connection("test1")[["authenticator"]],
    "oauth"
  )
})

test_that("generic environment variables are respected", {
  withr::local_envvar(
    c(
      SNOWFLAKE_ACCOUNT = "env_account",
      SNOWFLAKE_USER = "env_user",
      SNOWFLAKE_PASSWORD = "env_password",
      SNOWFLAKE_AUTHENTICATOR = "env_authenticator"
    )
  )

  expect_equal(
    snowflake_connection(.config_dir = tempdir())[["account"]],
    "env_account"
  )
})

test_that("generic environment variables are compatible with named connections", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "connections.toml")

  writeLines(
    c(
      "[test1]",
      'account = "testorg-test_account"',
      'user = "user"',
      'role = "role"',
      'authenticator = "SNOWFLAKE_JWT"'
    ),
    cfg
  )
  withr::local_envvar(
    c(
      SNOWFLAKE_PRIVATE_KEY_FILE = "/nexiste/env_private_key_file.p8"
    )
  )

  expect_equal(
    snowflake_connection("test1", .config_dir = config_dir)[[
      "private_key_file"
    ]],
    "/nexiste/env_private_key_file.p8"
  )
})

test_that("user-provided connection params win over config.toml file params", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      'default_connection_name = "test1"',
      "[connections.test1]",
      'account = "testorg-test_account"',
      'user = "user"',
      'password = "password"',
      'role = "role"',
      'authenticator = "externalbrowser"'
    ),
    cfg
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
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      'default_connection_name = "test1"',
      "[connections.test1]",
      'account = "testorg-test_account"',
      'role = "role"'
    ),
    cfg
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
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")
  connections <- file.path(config_dir, "connections.toml")

  writeLines(
    c(
      "[default]",
      'account = "testorg-test-account"',
      'user = "user"',
      'role = "role"',
      "",
      "[secondary]",
      'account = "secondary-test-account"',
      'user = "user"',
      'role = "role"'
    ),
    connections
  )
  writeLines(
    'default_connection_name = "secondary"',
    cfg
  )

  expect_equal(
    snowflake_connection(.config_dir = config_dir)[["account"]],
    "secondary-test-account"
  )
  expect_snapshot(
    snowflake_connection(.config_dir = config_dir),
    transform = quoted_path_transformer
  )
})

test_that("conflicting config.toml and connections.toml produce an error", {
  config_dir <- withr::local_tempdir()

  cfg <- file.path(config_dir, "config.toml")
  connections <- file.path(config_dir, "connections.toml")

  writeLines(
    c(
      "[default]",
      'account = "testorg-test-account"',
      'user = "user"',
      'role = "role"',
      "",
      "[secondary]",
      'account = "secondary-test-account"',
      'user = "user"',
      'role = "role"'
    ),
    connections
  )
  writeLines(
    'default_connection_name = "test1"',
    cfg
  )

  expect_error(snowflake_connection(.config_dir = config_dir))
})

test_that("SNOWFLAKE_DEFAULT_CONNECTION_NAME wins if set", {
  # Confirm that SNOWFLAKE_DEFAULT_CONNECTION_NAME is respected.
  withr::local_envvar(
    c(SNOWFLAKE_DEFAULT_CONNECTION_NAME = "test2")
  )

  expect_equal(
    snowflake_connection(.config_dir = test_path("."))[["account"]],
    "testorg-test_account2"
  )
})

test_that("without incoming field values, connections.toml is required", {
  config_dir <- withr::local_tempdir()
  expect_snapshot(
    snowflake_connection(.config_dir = config_dir),
    error = TRUE,
    transform = quoted_path_transformer
  )
})

test_that("with incoming field values, connections.toml is not required", {
  config_dir <- withr::local_tempdir()
  expect_snapshot(
    snowflake_connection(
      account = "testorg-test_account",
      user = "user",
      role = "role",
      authenticator = "externalbrowser",
      .config_dir = config_dir
    ),
    transform = quoted_path_transformer
  )
})

test_that("a default connection in config.toml is respected", {
  config_dir <- withr::local_tempdir()
  cfg <- file.path(config_dir, "config.toml")

  writeLines(
    c(
      "[connections.secondary]",
      'account = "secondary-test-account"',
      'user = "user"',
      'role = "role"',
      "[connections.default]",
      'account = "testorg-default"',
      'user = "default_user"',
      'role = "default_role"',
      'authenticator = "externalbrowser"'
    ),
    cfg
  )

  expect_equal(
    snowflake_connection(.config_dir = config_dir)[["account"]],
    "testorg-default"
  )

  withr::with_envvar(
    c(SNOWFLAKE_DEFAULT_CONNECTION_NAME = "secondary"),
    expect_equal(
      snowflake_connection(.config_dir = config_dir)[["account"]],
      "secondary-test-account"
    )
  )
})

test_that("Workbench-managed credentials are detected correctly", {
  # Emulate the config.toml and connections.toml files written by Workbench.
  config_dir <- withr::local_tempdir()
  cfg <- file.path(config_dir, "config.toml")
  connections <- file.path(config_dir, "connections.toml")

  writeLines('default_connection_name = "workbench"', cfg)
  writeLines(
    c(
      "[workbench]",
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
    snowflake_connection()
  )
})

test_that("ambient credentials are detected correctly", {
  expect_true(has_a_default_connection("test1", .config_dir = test_path(".")))
  config_dir <- tempfile("snowflake")
  expect_false(has_a_default_connection("test1", .config_dir = config_dir))
})
