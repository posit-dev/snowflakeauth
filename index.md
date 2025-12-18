# snowflakeauth

`snowflakeauth` is a toolkit for authenticating with Snowflake. It aims
for compatibility with the `connections.toml` and `config.toml` files
used by the [Snowflake Connector for
Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-connect)
and the [Snowflake
CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections),
so that R users can use a consistent approach to Snowflake credentials
across both languages.

`snowflakeauth` is intended for use by R package authors targeting the
Snowflake platform.

## Installation

You can install `snowflakeauth` from CRAN with:

``` r
install.packages("snowflakeauth")
```

Or, install the development version of `snowflakeauth` from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("posit-dev/snowflakeauth")
```

## Example

`snowflakeauth` can pick up on the default Snowflake connection
parameters from the `connections.toml` and `config.toml` files used by
the Python Connector for Snowflake and the Snowflake CLI (or any other
named connection, for that matter):

``` r
library(snowflakeauth)

snowflake_connection()

snowflake_connection(name = "testing")
```

or you can define the parameters of a connection manually:

``` r
snowflake_connection(
  account = "myaccount",
  user = "me",
  private_key_file = "rsa_key.p8",
  private_key_file_pwd = "supersecret"
)
```

These parameters can then be used to retrieve credentials, which take
the form of a one or more of HTTP headers:

``` r
conn <- snowflake_connection(
  account = "myaccount",
  user = "myuser@company.com",
  authenticator = "externalbrowser"
)

snowflake_credentials(conn)
```

## Supported Authentication Methods

The following table details authentication methods supported by
[`snowflake_credentials()`](https://posit-dev.github.io/snowflakeauth/reference/snowflake_credentials.md):

| Method                          | Supported | Notes                                    |
|---------------------------------|:---------:|:-----------------------------------------|
| Browser-based SSO               |    ✅     | Interactive, desktop-only                |
| Key-pair                        |    ✅     |                                          |
| OAuth token                     |    ✅     |                                          |
| Workload identity federation    |    ❌     |                                          |
| Programmatic access token (PAT) |    ❌     |                                          |
| OAuth 2.0 client credentials    |    ❌     | Rarely used, not planned                 |
| OAuth 2.0 authorization code    |    ❌     | Rarely used, not planned                 |
| Username and password           |    ❌     | Insecure, not planned                    |
| Username and password with MFA  |    ❌     | Not planned                              |
| Native SSO (Okta-only)          |    ❌     | Superceded by other methods, not planned |

## Limitations

- Browser-based authentication is known to fail in Positron, but should
  work in RStudio.

- No support for on-disk [connection
  caching](https://docs.snowflake.com/en/user-guide/admin-security-fed-auth-use#using-connection-caching-to-minimize-the-number-of-prompts-for-authentication-optional).

## License

MIT (c) [Posit Software, PBC](https://posit.co)
