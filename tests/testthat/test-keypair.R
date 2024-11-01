test_that("JWT generation works as expected", {
  skip_if_not_installed("jose")

  # Verify deterministic JWTs.
  jwt <- generate_jwt(
    "account", "user", test_path("test_rsa_key1.p8"),
    iat = 1730393963,
    jti = "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
  )
  expect_snapshot(jose::jwt_split(jwt))

  # Verify non-deterministic JWTs by checking against the wrong public key.
  jwt <- generate_jwt("account", "user", test_path("test_rsa_key1.p8"))
  expect_error(
    jose::jwt_decode_sig(jwt, test_path("test_rsa_key2.pub")),
    regexp = "incorrect signature"
  )
})
