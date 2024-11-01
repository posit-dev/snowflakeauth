#' Get credentials for a Snowflake connection
#'
#' @returns A list of HTTP headers.
#' @export
snowflake_credentials <- function(params,
                                  role = NULL,
                                  spcs_endpoint = NULL,
                                  ...) {
  role <- role %||% params$role
  switch(
    params$authenticator,
    oauth = list(
      Authorization = paste("Bearer", params$token),
      `X-Snowflake-Authorization-Token-Type` = "OAUTH"
    ),
    SNOWFLAKE_JWT = keypair_credentials(
      account = params$account,
      user = params$user,
      private_key = params$private_key_file %||% params$private_key,
      spcs_endpoint = spcs_endpoint,
      role = role
    ),
    cli::cli_abort(c(
      "Unsupported authenticator: {.str {params$authenticator}}.",
      "i" = "Only OAuth and key-pair authentication are supported."
    ))
  )
}
