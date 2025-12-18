# Snowflake connection parameter configuration

Reads Snowflake connection parameters from the `connections.toml` and
`config.toml` files used by the [Snowflake Connector for
Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect)
and the [Snowflake
CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections),
or specifies them for a connection manually.

## Usage

``` r
snowflake_connection(name = NULL, ..., .config_dir = NULL, .verbose = FALSE)
```

## Arguments

- name:

  A named connection. Defaults to `$SNOWFLAKE_DEFAULT_CONNECTION_NAME`
  if set, the `default_connection_name` from the `config.toml` file (if
  present), and finally the `[default]` section of the
  `connections.toml` file, if any. See [Snowflake's
  documentation](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#setting-a-default-connection)
  for details.

- ...:

  Additional connection parameters. See **Common parameters**.

- .config_dir:

  The directory to search for a `connections.toml` and `config.toml`
  file. Defaults to `$SNOWFLAKE_HOME` or `~/.snowflake` if that
  directory exists, otherwise it falls back to a platform-specific
  default. See [Snowflake's
  documentation](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect#connecting-using-the-connections-toml-file)
  for details.

- .verbose:

  Logical; if `TRUE`, prints detailed information about configuration
  loading, including which files are read and how connection parameters
  are resolved. Defaults to `FALSE`.

## Value

An object of class `"snowflake_connection"`.

## Common parameters

The following is a list of common connection parameters. A more complete
list can be found in the [documentation for the Snowflake Connector for
Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api#label-snowflake-connector-methods-connect):

- `account`: A Snowflake account identifier.

- `user`: A Snowflake username.

- `role`: The role to use for the connection.

- `schema`: The default schema to use for the connection.

- `database`: The default database to use for the connection.

- `warehouse`: The default warehouse to use for the connection.

- `authenticator`: The authentication method to use for the connection.

- `private_key` or `private_key_file`: A path to a PEM-encoded private
  key for key-pair authentication.

- `private_key_file_pwd`: The passphrase for the private key, if any.

- `token`: The OAuth token to use for authentication.

- `token_file_path`: A path to an OAuth token to use for authentication.

- `password`: The user's Snowflake password.

## Examples

``` r
if (FALSE) { # has_a_default_connection()
# Read the default connection parameters from an existing
# connections.toml file:
conn <- snowflake_connection()

# Read a named connection from an existing connections.toml file:
conn <- snowflake_connection(name = "default")

# Override specific parameters for a connection:
conn <- snowflake_connection(
  schema = "myschema",
  warehouse = "mywarehouse"
)
}
# Pass connection parameters manually, which is useful if there is no
# connections.toml file. For example, to use key-pair authentication:
conn <- snowflake_connection(
  account = "myaccount",
  user = "me",
  private_key = "rsa_key.p8"
)
```
