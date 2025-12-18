# Changelog

## snowflakeauth (development version)

- Misleading warnings about the `config.toml` and `connections.toml`
  files both existing have been removed
  ([\#25](https://github.com/posit-dev/snowflakeauth/issues/25)).

## snowflakeauth 0.2.0

CRAN release: 2025-09-02

- `jose` and `openssl` have been upgraded to required dependencies.
- Paths are expanded when `SNOWFLAKE_HOME` is set.
- `private_key_path` is permitted as a paramter when using JWT
  authentication.
- [`snowflake_connection()`](https://posit-dev.github.io/snowflakeauth/reference/snowflake_connection.md)
  gains a `.verbose` parameter for more detailed logging of connection
  loading.

## snowflakeauth 0.1.2

CRAN release: 2025-06-19

- Initial release. `snowflakeauth` is a toolkit for authenticating with
  Snowflake. It aims for compatibility with the `connections.toml` and
  `config.toml` files used by the Snowflake Connector for Python and the
  Snowflake CLI.
