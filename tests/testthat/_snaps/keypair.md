# JWT generation works as expected

    Code
      jose::jwt_split(jwt)
    Output
      $type
      [1] "RSA"
      
      $keysize
      [1] 256
      
      $data
        [1] 65 79 4a 30 65 58 41 69 4f 69 4a 4b 56 31 51 69 4c 43 4a 68 62 47 63 69 4f
       [26] 69 4a 53 55 7a 49 31 4e 69 4a 39 2e 65 79 4a 70 63 33 4d 69 4f 69 4a 42 51
       [51] 30 4e 50 56 55 35 55 4c 6c 56 54 52 56 49 75 55 30 68 42 4d 6a 55 32 4f 6b
       [76] 6c 47 64 31 45 30 59 31 6f 7a 56 54 6b 7a 52 47 39 72 5a 57 35 7a 62 6c 51
      [101] 76 62 46 56 73 62 44 46 5a 54 57 70 7a 63 6c 4e 77 4e 46 64 59 52 31 5a 34
      [126] 55 48 63 7a 53 30 30 39 49 69 77 69 63 33 56 69 49 6a 6f 69 51 55 4e 44 54
      [151] 31 56 4f 56 43 35 56 55 30 56 53 49 69 77 69 5a 58 68 77 49 6a 6f 78 4e 7a
      [176] 4d 77 4d 7a 6b 30 4d 6a 59 7a 4c 43 4a 75 59 6d 59 69 4f 6a 45 33 4d 7a 41
      [201] 7a 4f 54 4d 35 4e 6a 4d 73 49 6d 6c 68 64 43 49 36 4d 54 63 7a 4d 44 4d 35
      [226] 4d 7a 6b 32 4d 79 77 69 61 6e 52 70 49 6a 6f 69 61 6c 63 35 53 6a 5a 58 56
      [251] 6b 55 78 52 47 35 45 4d 56 5a 52 5a 33 56 4f 63 58 6b 78 62 7a 4e 49 64 31
      [276] 64 69 52 54 4e 51 56 32 77 34 56 48 6b 34 55 6e 42 42 65 6d 51 79 52 53 4a
      [301] 39
      
      $sig
        [1] 39 79 ff 35 7e 0a 99 eb 29 1a 5b 39 82 78 2e 6d 24 59 00 db 43 f1 c0 b7 1d
       [26] 9e eb 94 25 66 d0 04 6d 22 1d 51 dc 16 46 b0 0d 93 6c f4 66 b2 e5 25 a1 05
       [51] 5d 3d 30 86 22 74 39 0b 19 64 49 08 3e 7d 62 93 9d d3 90 7a 88 97 29 24 0c
       [76] 0f 56 db 37 53 95 57 7e 05 6b a8 f0 9b ea e8 f8 f2 5f 3a 80 51 3f 49 76 50
      [101] dc 82 e5 3d b0 58 74 47 22 1c ba 76 12 b6 63 ee 22 f2 e2 75 3a 9c e6 71 13
      [126] fd 9e 0d 18 25 84 7d 91 50 93 c2 41 ae 66 86 df ef 1d 4a 28 08 5e 3f 69 89
      [151] 2c bc d3 57 c1 c8 cd 6f a6 b2 43 23 5c 43 4f eb d6 0b d6 21 9b 2e 19 3a 32
      [176] a3 5c 89 a1 14 c9 b9 2c 49 e1 66 b1 6a 52 35 cb 9e 9b d3 db c2 64 f6 82 68
      [201] 99 8f 55 f5 5b cb ee ac 3b 3f e9 5a c8 31 64 c8 15 f3 01 09 d0 2f ff 13 01
      [226] 2a 02 a3 db 66 54 0c 49 58 ce 65 36 2a 8b 13 9f fd 0a 6a ad f4 44 ce 6c f2
      [251] f8 eb da e4 30 3f
      
      $payload
      $payload$iss
      [1] "ACCOUNT.USER.SHA256:IFwQ4cZ3U93DokensnT/lUll1YMjsrSp4WXGVxPw3KM="
      
      $payload$sub
      [1] "ACCOUNT.USER"
      
      $payload$exp
      [1] 1730394263
      
      $payload$nbf
      [1] 1730393963
      
      $payload$iat
      [1] 1730393963
      
      $payload$jti
      [1] "jW9J6WVE1DnD1VQguNqy1o3HwWbE3PWl8Ty8RpAzd2E"
      
      
      $header
      $header$typ
      [1] "JWT"
      
      $header$alg
      [1] "RS256"
      
      

# exchange_jwt_for_token handles errors correctly

    Code
      exchange_jwt_for_token("https://testaccount.snowflakecomputing.com", "test_jwt",
        "test.endpoint.com")
    Condition
      Error in `exchange_jwt_for_token()`:
      ! Could not exchange JWT
      Status code: 401
      Response: Unauthorized

