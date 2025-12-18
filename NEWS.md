# snowflakeauth (development version)

* Misleading warnings about the `config.toml` and `connections.toml` files both
  existing have been removed (#25).
* Error messages when a named connection is requested but the `connections.toml`
  file does not exist are now clearer (#23).
* Error messages when `connections.toml` exists but lacks a needed connection are
  now more specific and helpful (#26).
* Add support for `externalbrowser` authentication.

# snowflakeauth 0.2.0

* `jose` and `openssl` have been upgraded to required dependencies.
* Paths are expanded when `SNOWFLAKE_HOME` is set.
* `private_key_path` is permitted as a paramter when using JWT authentication.
* `snowflake_connection()` gains a `.verbose` parameter for more detailed logging of connection loading.

# snowflakeauth 0.1.2

* Initial release. `snowflakeauth` is a toolkit for authenticating with Snowflake. It aims for compatibility with the `connections.toml` and `config.toml` files used by the Snowflake Connector for Python and the Snowflake CLI.
