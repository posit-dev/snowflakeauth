#' Get credentials for a Snowflake connection
#' @param params a list of connection parameters from `[snowflake_connection()]``
#' @param role a snowflake entity
#' @param spcs_endpoint a Snowpark Container Services ingress URL, formatted (*-accountname.snowflakecomputing.app)
#' @param ... Additional Snowflake connection parameters
#'
#' @returns A list of HTTP headers.
#' @export
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
      params$private_key_file %||% params$private_key,
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
  paste(
    mapply(
      function(name, value) {
        paste0(curl::curl_escape(name), "=", curl::curl_escape(value))
      },
      names(form_data),
      form_data
    ),
    collapse = "&"
  )
}
