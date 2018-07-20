defmodule AWS do
  alias AWS.Client
  alias AWS.Request
  def request(client, url, service, action, method, headers, input, options \\ []) do
    client = %{client | service: service}
    host = get_host(client, service)
    url = get_url(client, host, url)
    IO.puts(url)
    headers = Enum.concat([{"Host", host}], headers)
    {:ok, payload} = if input != nil, do: Poison.encode(input), else: ""

    headers = Request.sign_v4(client, method, url, [], headers, payload)

    HTTPoison.request(method, url, payload, headers, options)
  end
  defp get_host(%Client{} = client, prefix),
    do: if client.region == "local", do: "localhost", else: "#{prefix}.#{client.region}.#{client.endpoint}"

  defp get_url(client, host, url), do: "#{client.proto}://#{host}:#{client.port}#{url}"
end
