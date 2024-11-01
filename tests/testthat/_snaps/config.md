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
      account: "testorg-test_account"
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
      snowflake_connection("test5", .config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! The test5 connection is missing the required account field.
      i Try defining an account in the [test5] section of './connections.toml'.

---

    Code
      snowflake_connection(.config_dir = dir)
    Condition
      Error in `snowflake_connection()`:
      ! The default connection is missing.
      i Try defining a [default] section in './connections.toml'.

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

# connections can be created without a connections.toml file

    Code
      snowflake_connection(.config_dir = "/test")
    Condition
      Error in `snowflake_connection()`:
      ! The `account` argument is required when '/test/connections.toml' is missing or empty.
      i Pass `account` or define a [default] section with an account field in '/test/connections.toml'.

---

    Code
      snowflake_connection(account = "testorg-test_account", user = "user", role = "role",
        authenticator = "externalbrowser", .config_dir = "/test")
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
      <Snowflake connection: workbench>
      account: "testorg-test_account"
      authenticator: "oauth"
      token: <REDACTED>

