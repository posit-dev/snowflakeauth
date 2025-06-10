# exchange_oauth_token handles missing token in response

    Code
      exchange_oauth_token("https://testaccount.snowflakecomputing.com", "test_token",
        "test.endpoint.com")
    Condition
      Error in `exchange_oauth_token()`:
      ! Unexpected response from server: {"data": {"message": "No token provided"}}

