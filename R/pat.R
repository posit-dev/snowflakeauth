pat_credentials <- function(token = NULL, token_file = NULL) {
  if (!is.null(token_file)) {
    tryCatch(
      token <- readLines(token_file, warn = FALSE, encoding = "UTF-8"),
      error = function(e) {
        cli::cli_abort(
          "Failed to read PAT token from {.file {token_file}}.",
          parent = e
        )
      }
    )
    if (length(token) != 1L || !nzchar(token[[1]])) {
      cli::cli_abort(
        "PAT token file {.file {token_file}} must contain exactly one non-empty line."
      )
    }
  }

  list(
    Authorization = paste("Bearer", token),
    `X-Snowflake-Authorization-Token-Type` = "PROGRAMMATIC_ACCESS_TOKEN"
  )
}
