# Get credentials for a Snowflake connection

Get credentials for a Snowflake connection

## Usage

``` r
snowflake_credentials(params, role = NULL, spcs_endpoint = NULL, ...)
```

## Arguments

- params:

  a list of connection parameters from
  \`[`snowflake_connection()`](https://posit-dev.github.io/snowflakeauth/reference/snowflake_connection.md)“

- role:

  a snowflake entity

- spcs_endpoint:

  a Snowpark Container Services ingress URL, formatted
  (\*-accountname.snowflakecomputing.app)

- ...:

  Additional Snowflake connection parameters

## Value

A list of HTTP headers.

## Examples

``` r
if (FALSE) { # has_a_default_connection() && interactive()
# Obtain authentication headers for accessing Snowflake APIs
snowflake_credentials(
 snowflake_connection()
)
}
if (FALSE) { # has_a_default_connection() && interactive()
# If the application is in Snowpark Container Services,
# a different collection of headers are returned:
snowflake_credentials(
 snowflake_connection(),
 spcs_endpoint = "https://example-accountname.snowflakecomputing.app"
)
}
```
