# the connections.toml file is parsed correctly

    Code
      snowflake_connection("test1", .config_dir = dir)
    Message
      <Snowflake connection: test1>
      account: "testorg-test_account"
      authenticator: "oauth"
      token: <REDACTED>
      user: "user"

---

    Code
      snowflake_connection("test2", .config_dir = dir)
    Message
      <Snowflake connection: test2>
      account: "testorg-test_account2"
      private_key_file: "file"
      private_key_file_pwd: <REDACTED>
      user: "user"
      authenticator: "SNOWFLAKE_JWT"

---

    Code
      snowflake_connection("test3", .config_dir = dir)
    Message
      <Snowflake connection: test3>
      account: "testorg-test_account"
      authenticator: "externalbrowser"
      role: "role"
      user: "user"

---

    Code
      snowflake_connection("test4", .config_dir = dir)
    Message
      <Snowflake connection: test4>
      account: "testorg-test_account"
      password: <REDACTED>
      role: "role"
      user: "user"
      authenticator: "snowflake"

---

    Code
      snowflake_connection("test6", .config_dir = dir)
    Message
      <Snowflake connection: test6>
      account: "testorg-test_account"
      authenticator: "oauth"
      token_file_path: "/test/token"
      user: "user"

---

    Code
      snowflake_connection("test5", .config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! An `account` parameter is required when './connections.toml' is missing or empty.
      i Pass `account` or define a [test5] section with an account field in './connections.toml'.

---

    Code
      snowflake_connection("test7", .config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! One of `token` or `token_file_path` is required when using OAuth authentication.

---

    Code
      snowflake_connection("test8", .config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! A `user` parameter is required when using key-pair authentication.

---

    Code
      snowflake_connection(.config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! An `account` parameter is required when './connections.toml' is missing or empty.
      i Pass `account` or define a [] section with an account field in './connections.toml'.

---

    Code
      snowflake_connection("test3", private_key_file = "file", schema = "schema",
        warehouse = "warehouse", .config_dir = dir)
    Message
      <Snowflake connection: test3>
      account: "testorg-test_account"
      authenticator: "SNOWFLAKE_JWT"
      role: "role"
      user: "user"
      private_key_file: "file"
      schema: "schema"
      warehouse: "warehouse"

# connections.toml wins if present with config.toml

    Code
      snowflake_connection(.config_dir = config_dir)
    Message
      ! Both 'connections.toml' and 'config.toml' exist. Using 'connections.toml'.
      <Snowflake connection: secondary>
      account: "secondary-test-account"
      role: "role"
      user: "user"
      authenticator: "snowflake"

# without incoming field values, connections.toml is required

    Code
      snowflake_connection(.config_dir = config_dir)
    Condition
      Error in `snowflake_connection()`:
      ! An `account` parameter is required when '/CONFIG_DIR/connections.toml' is missing or empty.
      i Pass `account` or define a [] section with an account field in '/CONFIG_DIR/connections.toml'.

# with incoming field values, connections.toml is not required

    Code
      snowflake_connection(account = "testorg-test_account", user = "user", role = "role",
        authenticator = "externalbrowser", .config_dir = config_dir)
    Message
      <Snowflake connection>
      account: "testorg-test_account"
      user: "user"
      role: "role"
      authenticator: "externalbrowser"

# Workbench-managed credentials are detected correctly

    Code
      snowflake_connection()
    Message
      ! Both 'connections.toml' and 'config.toml' exist. Using 'connections.toml'.
      <Snowflake connection: workbench>
      account: "testorg-test_account"
      authenticator: "oauth"
      token: <REDACTED>

