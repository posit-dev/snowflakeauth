# Keyring-based ID token cache for cross-session persistence and Snowflake
# Python Connector interoperability.

use_keyring <- function() {
  rlang::is_installed("keyring") &&
    keyring::has_keyring_support() &&
    !keyring::keyring_is_locked()
}

keyring_cache_token <- function(account, user, token_type, token, expires_at) {
  service <- keyring_service(account, user, token_type)
  payload <- jsonlite::toJSON(
    list(token = token, expires_at = expires_at),
    auto_unbox = TRUE,
    null = "null"
  )
  tryCatch(
    keyring::key_set_with_value(service, toupper(user), payload),
    error = function(e) {
      cli::cli_abort("Failed to cache {token_type} in keyring", parent = e)
    }
  )
}

keyring_get_token <- function(account, user, token_type) {
  service <- keyring_service(account, user, token_type)
  payload <- tryCatch(
    keyring::key_get(service, toupper(user)),
    error = function(e) NULL
  )
  if (is.null(payload)) {
    return(NULL)
  }
  cached <- jsonlite::fromJSON(payload)
  if (has_expired(cached$expires_at)) {
    return(NULL)
  }
  cached
}

keyring_clear_token <- function(account, user, token_type) {
  service <- keyring_service(account, user, token_type)
  tryCatch(
    keyring::key_delete(service, toupper(user)),
    error = function(e) {
      cli::cli_abort("Failed to clear {token_type} from keyring", parent = e)
    }
  )
}

# Compute a Python Connector-compatible keyring service name.
keyring_service <- function(account, user, token_type) {
  if (!grepl("snowflakecomputing.com", account, fixed = TRUE)) {
    account <- paste0(account, ".snowflakecomputing.com")
  }
  paste(toupper(account), toupper(user), token_type, sep = ":")
}
