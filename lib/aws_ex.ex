defmodule AWS do
  alias AWS.{Client, Request, Cognito}
  alias AWS.Request.Signer

  def request(%Request{} = request, %Client{} = client, options \\ []) do
    # request = request
    # |> Request.encode!(:payload)
    # |> Signer.sign_v4(client, hashed: options[:hashed] || false)

    url = Request.url(client, request)
    url = if length(request.query_params) >= 1, do: url <> "?" <> URI.encode_query(request.query_params), else: url
    IO.puts url
    with {:ok, response} <- HTTPoison.request(request.method, url, request.payload, request.headers, options) do
      {:ok, request.parser.(response)}
    end
  end
  def request!(%Request{} = request, %Client{} = client, options \\ []) do
    case request(request, client, options) do
      {:ok, response} ->
        response
      {:err, response} ->
        raise RuntimeError, message: inspect(response)
    end
  end
  def sign_v4(request, client, options \\ []), do: request |> Request.encode!(:payload) |> Signer.sign_v4(client, options)

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
