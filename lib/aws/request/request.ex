defmodule AWS.Request do
  alias AWS.{Client, Request}

  defstruct [
    :service,
    :host,
    :path,
    :method,
    headers: [],
    query_params: [],
    payload: ""
  ]

  def url(%Client{} = client, %Request{} = request) do
    endpoint = "#{client.proto}://#{request.host}:#{client.port}#{request.path}"
  end

  def encode!(%Request{} = request, :payload), do: %{request| payload: Poison.encode!(request.payload)}
end
