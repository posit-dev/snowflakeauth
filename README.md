
<!-- README.md is generated from README.Rmd. Please edit that file -->

# snowflakeauth

<!-- badges: start -->

[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html)
[![R-CMD-check](https://github.com/posit-dev/snowflakeauth/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/posit-dev/snowflakeauth/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

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

snowflake_connection(
  account = "myaccount",
  user = "me",
  authenticator = "externalbrowser"
)
```

These parameters can then be used to retrieve credentials, which take
the form of a one or more of HTTP headers:

``` r
conn <- snowflake_connection(
  account = "myaccount",
  user = "me",
  authenticator = "oauth",
  token = "token"
)

snowflake_credentials(conn)
```

## Limitations

- No support for SSO authentication using a browser.

- No support for [connection
  caching](https://docs.snowflake.com/en/user-guide/admin-security-fed-auth-use#using-connection-caching-to-minimize-the-number-of-prompts-for-authentication-optional).

- No support for direct username/password authentication,
  username/password authentication with MFA, or [“Native SSO”
  authentication](https://docs.snowflake.com/en/user-guide/admin-security-fed-auth-use#native-sso-okta-only),
  (which is Okta-only). These are not planned; please migrate to OAuth
  or key-pair authentication when a browser is not available.

## License

MIT (c) [Posit Software, PBC](https://posit.co)
