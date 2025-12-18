# Reports whether a default connection is available

Reports whether a default connection is available

## Usage

``` r
has_a_default_connection(...)
```

## Arguments

- ...:

  arguments passed to
  [`snowflake_connection()`](https://posit-dev.github.io/snowflakeauth/reference/snowflake_connection.md)

## Value

Logical value indicating whether a default connection is available.

## Examples

``` r
has_a_default_connection()
#> [1] FALSE
```
