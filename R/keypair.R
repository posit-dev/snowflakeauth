# Support for Snowflake key-pair authentication for SPCS and the REST API.
keypair_credentials <- function(
  account,
  user,
  private_key,
  spcs_endpoint = NULL,
  role = "PUBLIC"
) {
  jwt <- generate_jwt(account, user, private_key)
  # Important: the SPCS ingress handles key-pair authentication *differently*
  # than the REST API. In particular, we can't pass the signed JWT as a bearer
  # token, we have to go through an exchange step.
  if (is.null(spcs_endpoint)) {
    return(list(
      Authorization = paste("Bearer", jwt),
      # Snowflake requires this additional header for JWTs, presumably to
      # distinguish them from OAuth access tokens.
      `X-Snowflake-Authorization-Token-Type` = "KEYPAIR_JWT"
    ))
  }

  # strip scheme from SPCS endpoint if provided
  if (grepl("^https?://", spcs_endpoint)) {
    spcs_endpoint <- sub("^https?://", "", spcs_endpoint)
  }
  account_url <- sprintf("https://%s.snowflakecomputing.com", account)
  token <- exchange_jwt_for_token(account_url, jwt, spcs_endpoint, role)
  # Yes, this is actually the format of the Authorization header that SPCS
  # requires.
  return(list(
    Authorization = sprintf('Snowflake Token="%s"', token$access_token)
  ))
}

# Generate a JWT that can be used for Snowflake "key-pair" authentication.
generate_jwt <- function(account, user, private_key, iat = NULL, jti = NULL) {
  check_installed("jose", "for key-pair authentication")
  key <- openssl::read_key(private_key)
  if (is.null(iat)) {
    iat <- as.integer(Sys.time())
  }
  if (is.null(jti)) {
    jti <- openssl::base64_encode(openssl::rand_bytes(32))
    jti <- gsub("=+$", "", jti)
    jti <- gsub("+", "-", jti, fixed = TRUE)
    jti <- gsub("/", "_", jti, fixed = TRUE)
  }
  # We can't use openssl::fingerprint() here because it uses a different
  # algorithm than Snowflake does.
  fp <- openssl::base64_encode(openssl::sha256(openssl::write_der(key$pubkey)))
  sub <- toupper(paste0(account, ".", user))
  # Note: Snowflake employs a malformed issuer claim, so we have to inject it
  # manually after jose's validation phase.
  claim <- jose::jwt_claim(
    iss = "dummy",
    sub = sub,
    iat = iat,
    # Expire in 5 minutes.
    exp = iat + 300L,
    # TODO: These claims are ignored by Snowflake. Should we omit them?
    nbf = iat,
    jti = jti
  )
  claim$iss <- paste0(sub, ".SHA256:", fp)
  jose::jwt_encode_sig(claim, key)
}

# Exchange a JWT for a Snowflake OAuth access token.
#
# Note: we can't use httr2::oauth_flow_bearer_jwt() because Snowflake does not
# adhere closely enough to RFC 7523. In particular, the response format is not
# JSON, and the JWT uses a malformed issuer claim that jose::jwt_claim() can't
# handle.
#
# See: https://docs.snowflake.com/en/user-guide/oauth-custom#label-oauth-token-exchange
exchange_jwt_for_token <- function(
  account_url,
  jwt,
  spcs_endpoint,
  role = "PUBLIC"
) {
  scope <- sprintf("session:role:%s %s", role, spcs_endpoint)
  url <- sprintf("%s/oauth/token", account_url)

  payload <- list(
    grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
    scope = scope,
    assertion = jwt
  )

  handle <- curl::new_handle()
  curl::handle_setopt(handle, postfields = formEncode(payload))
  curl::handle_setheaders(
    handle,
    `Content-Type` = "application/x-www-form-urlencoded",
    `Accept` = "application/json"
  )

  resp <- curl::curl_fetch_memory(url, handle)

  if (resp$status_code >= 400) {
    cli::cli_abort(c(
      "Could not exchange JWT",
      "Status code: {.strong {resp$status_code}}",
      "Response: {rawToChar(resp$content)}"
    ))
  }

  token <- rawToChar(resp$content)
  list(access_token = token, expires_in = 300L)
}
