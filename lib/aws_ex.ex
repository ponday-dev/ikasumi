defmodule AWS do
  alias AWS.{Client, Request, Cognito}
  alias AWS.Request.Signer

  def request(%Client{} = client, %Request{} = request, options \\ []) do
    request = request
    |> Request.encode!(:payload)
    |> Signer.sign_v4(client)

    url = Request.url(client, request)
    url = if length(request.query_params) >= 1, do: url <> "?" <> URI.encode_query(request.query_params), else: url
    HTTPoison.request(request.method, url, request.payload, request.headers, options)
  end

  def get_credentials(client, identity_id) do
    with {:ok, %{"Credentials" => credentials}, _}<- Cognito.get_credentials_for_identity(client, identity_id) do
      %{client |
        access_key: Map.get(credentials, "AccessKeyId"),
        secret_access_key: Map.get(credentials, "SecretKey"),
        credentials: credentials
      }
    end
  end
end
