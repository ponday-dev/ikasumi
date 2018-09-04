defmodule Ikasumi.Request do
  alias Ikasumi.{Client, Request}
  import Ikasumi.Util, only: [identity: 1]

  defstruct [
    :service,
    :host,
    :path,
    :method,
    headers: [],
    query_params: [],
    payload: "",
    parser: &identity/1
  ]

  def url(%Client{} = client, %Request{} = request) do
    "#{client.proto}://#{request.host}:#{client.port}#{request.path}"
  end

  def encode!(%Request{} = request, :payload) do
    if is_binary(request.payload) do
      request
    else
      %{request| payload: Poison.encode!(request.payload)}
    end
  end
end
