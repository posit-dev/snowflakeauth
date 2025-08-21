# snowflakeauth (development version)

* `jose` and `openssl` have been upgraded to required dependencies.
* Paths are expanded when `SNOWFLAKE_HOME` is set.
* `private_key_path` is permitted as a paramter when using JWT authentication.

# snowflakeauth 0.1.2

* Initial release. `snowflakeauth` is a toolkit for authenticating with Snowflake. It aims for compatibility with the `connections.toml` and `config.toml` files used by the Snowflake Connector for Python and the Snowflake CLI.
