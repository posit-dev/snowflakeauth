test_that("has_expired returns TRUE when token is already expired", {
  now <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expires_at <- as.integer(now) - 1L
  expect_true(has_expired(expires_at, .now = now))
})

test_that("has_expired returns TRUE when token expires within 5 minutes", {
  now <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expires_at <- as.integer(now) + 299L
  expect_true(has_expired(expires_at, .now = now))
})

test_that("has_expired returns FALSE when token expires after 5 minutes", {
  now <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expires_at <- as.integer(now) + 301L
  expect_false(has_expired(expires_at, .now = now))
})

test_that("has_expired returns TRUE when expires_at is NULL", {
  expect_true(has_expired(NULL))
})
