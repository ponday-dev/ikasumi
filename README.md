# Ikasumi

Elixir用のシンプルなAWSクライアントです。  

# Usage

```elixir
client =
  %Ikasumi.Client {
    access_key: "abcdefghijklmn",
    secret_access_key: "opqrstuvwxyz",
    region: "us-east-1",
    endpoint: "amazonaws.com",
    user_pool_id: "1234567890"
  }
  |> Ikasumi.Cognito.get_credentials_for_identity("abcdefg")

Ikasumi.S3.upload(client, :file, "sample.txt", "examplebucket", "sample.txt")
```
