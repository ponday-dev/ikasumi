defmodule AWS do
  alias AWS.{Client, Request}
  alias AWS.Request.Signer

  def request(%Client{} = client, %Request{} = request, options \\ []) do
    request = request
    |> Request.encode!(:payload)
    |> Signer.sign_v4(client)

    url = Request.url(client, request)
    url = if length(request.query_params) >= 1, do: url <> "?" <> URI.encode_query(request.query_params), else: url
    HTTPoison.request(request.method, url, request.payload, request.headers, options)
  end
end
