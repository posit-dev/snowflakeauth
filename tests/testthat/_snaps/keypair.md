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
       [51] 30 4e 50 56 55 35 55 4c 6c 56 54 52 56 49 75 55 30 68 42 4d 6a 55 32 4f 6c
       [76] 56 34 55 6e 4a 33 65 57 4e 44 55 53 38 78 57 6b 6c 47 63 48 6b 72 65 6c 45
      [101] 34 4e 48 42 6e 4e 45 4e 50 5a 32 74 44 4b 32 4e 56 63 6e 4a 4a 57 48 5a 46
      [126] 4c 7a 55 76 61 57 4d 39 49 69 77 69 63 33 56 69 49 6a 6f 69 51 55 4e 44 54
      [151] 31 56 4f 56 43 35 56 55 30 56 53 49 69 77 69 5a 58 68 77 49 6a 6f 78 4e 7a
      [176] 4d 77 4d 7a 6b 30 4d 6a 59 7a 4c 43 4a 75 59 6d 59 69 4f 6a 45 33 4d 7a 41
      [201] 7a 4f 54 4d 35 4e 6a 4d 73 49 6d 6c 68 64 43 49 36 4d 54 63 7a 4d 44 4d 35
      [226] 4d 7a 6b 32 4d 79 77 69 61 6e 52 70 49 6a 6f 69 61 6c 63 35 53 6a 5a 58 56
      [251] 6b 55 78 52 47 35 45 4d 56 5a 52 5a 33 56 4f 63 58 6b 78 62 7a 4e 49 64 31
      [276] 64 69 52 54 4e 51 56 32 77 34 56 48 6b 34 55 6e 42 42 65 6d 51 79 52 53 4a
      [301] 39
      
      $sig
        [1] 7b 67 29 bc 7c 9c 75 9d 0d c9 b6 02 11 5b 06 70 10 33 a4 7a c6 c8 ea c2 aa
       [26] aa 7e 42 a7 b1 85 fa 64 a9 9a 66 0a 1b 4b d3 58 2b 78 fb 3d 75 d6 c8 60 36
       [51] 0a 97 e9 25 f4 9e 36 c5 4b 57 77 8c bc 79 5e b3 d7 85 09 e5 60 46 09 4c 7e
       [76] b1 0e 6e d2 2e 22 ba a1 54 49 9f 88 b0 26 e8 49 fe bb 29 83 0d d1 16 6f 7e
      [101] ac c3 cf 8e 4c d2 72 0c ac cc f8 1f b9 78 7b 33 d3 71 f2 83 4f 0b 71 21 f9
      [126] 44 e4 f5 25 6d 78 48 f2 ed c6 c0 38 2f 50 a6 45 92 a4 e6 ec c2 3c f0 82 1f
      [151] ed fe ed d6 8a 7a 76 01 d3 d5 ed 3d 26 d5 25 d2 5d 5a 0a 45 0a 70 b2 7a 0e
      [176] ee fd 6b 56 58 27 19 86 39 5d b7 49 10 e8 a3 6c 33 b8 61 40 5c f9 63 60 3b
      [201] 1f 10 c2 1c 76 c7 38 00 66 27 b4 4f 3a 26 fb f0 96 0a c0 09 a8 62 1d a4 3a
      [226] ad 83 64 f8 13 94 62 21 ab 11 8c 07 ed b2 6f 4b d6 8a 4d 98 06 54 03 05 e7
      [251] 4b 65 dd fa 53 8f
      
      $payload
      $payload$iss
      [1] "ACCOUNT.USER.SHA256:UxRrwycCQ/1ZIFpy+zQ84pg4COgkC+cUrrIXvE/5/ic="
      
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

