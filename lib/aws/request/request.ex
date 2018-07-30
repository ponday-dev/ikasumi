defmodule AWS.Request do
  alias AWS.{Client, Request}
  import AWS.Util, only: [identity: 1]

  defstruct [
    :service,
    :host,
    :path,
    :method,
    headers: [],
    query_params: [],
    payload: "",
    parser: &identity/1
    datetime: nil,
    hashed_payload: nil,
    hashed_request: nil,
    credential_scope: nil,
    signing_key: nil,
    string_to_sign: nil,
    signature: nil
  ]

  def url(%Client{} = client, %Request{} = request) do
    endpoint = "#{client.proto}://#{request.host}:#{client.port}#{request.path}"
  end

  def encode!(%Request{} = request, :payload) do
    if is_binary(request.payload) do
      request
    else
      %{request| payload: Poison.encode!(request.payload)}
    end
  end
end
