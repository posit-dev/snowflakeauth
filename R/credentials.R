#' Get credentials for a Snowflake connection
#' @param params a list of connection parameters from `[snowflake_connection()]``
#' @param role a snowflake entity
#' @param spcs_endpoint a Snowpark Container Services ingress URL, formatted (*-accountname.snowflakecomputing.app)
#' @param ... Additional Snowflake connection parameters
#'
#' @returns A list of HTTP headers.
#' @export
#' @examplesIf has_a_default_connection()
#' # Obtain authentication headers for accessing Snowflake APIs
#' snowflake_credentials(
#'  snowflake_connection()
#' )
#' @examplesIf has_a_default_connection()
#' # If the application is in Snowpark Container Services,
#' # a different collection of headers are returned:
#' snowflake_credentials(
#'  snowflake_connection(),
#'  spcs_endpoint = "https://example-accountname.snowflakecomputing.app"
#' )
snowflake_credentials <- function(
  params,
  role = NULL,
  spcs_endpoint = NULL,
  ...
) {
  role <- role %||% params$role
  switch(
    params$authenticator,
    oauth = oauth_credentials(
      params$account,
      params$token,
      params$token_file_path,
      spcs_endpoint
    ),
    SNOWFLAKE_JWT = keypair_credentials(
      params$account,
      params$user,
      params$private_key_file %||%
        params$private_key %||%
        params$private_key_path,
      params$private_key_file_pwd,
      spcs_endpoint,
      role
    ),
    cli::cli_abort(c(
      "Unsupported authenticator: {.str {params$authenticator}}.",
      "i" = "Only OAuth and key-pair authentication are supported."
    ))
  )
}

formEncode <- function(form_data) {
  paste0(
    curl::curl_escape(names(form_data)),
    "=",
    curl::curl_escape(form_data),
    collapse = "&"
  )
}
