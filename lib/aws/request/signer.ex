defmodule AWS.Request.Signer do
  alias AWS.{Client, Request}
  alias AWS.Request.Signer.Internal
  import AWS.Util, only: [to_amz_datetime: 1, hash: 1, hex_encode: 1]

  def sign_v4(%Request{} = request, %Client{} = client, options \\ []), do: sign_v4(request, client, Timex.now(), options)
  def sign_v4(%Request{} = request, %Client{} = client, datetime, options) do
    amz_datetime = to_amz_datetime(datetime)

    request_for_sign = if options[:hashed] do
      %{request | payload: request.payload |> hash() |> hex_encode() }
    else
      request
    end
    headers = [
      { "host", request_for_sign.host },
      { "x-amz-date", amz_datetime }
      | request_for_sign.headers ]
    headers = if !is_nil(client.credentials) do
      [{"x-amz-security-token", Map.get(client.credentials, "SessionToken")} | headers]
    else
      headers
    end

    request_for_sign = %{request_for_sign | headers: headers}
    hashed_request = Internal.canonical_request(request_for_sign)
    credential_scope = Internal.credential_scope(amz_datetime, client.region, request_for_sign.service)

    signing_key = Internal.calc_signing_key(client.secret_access_key, amz_datetime, client.region, request_for_sign.service)
    string_to_sign = Internal.string_to_sign(amz_datetime, credential_scope, hashed_request)
    signature = Internal.calc_signature(signing_key, string_to_sign)
    authorization = Internal.authorization_header(client.access_key, credential_scope, headers, signature)

    request = %{request | headers: [{ "Authorization", authorization } | headers]}
    if options[:signature], do: {signature, request}, else: request
  end
end

defmodule AWS.Request.Signer.Internal do
  alias AWS.Client
  import AWS.Util, only: [hash: 1, hmac: 2, hex_encode: 1, short_date: 1]

  def canonical_request(%{method: method, path: path, query_params: query_params, headers: headers, payload: payload}) do
    method = (if is_atom(method), do: Atom.to_string(method), else: method) |> String.upcase()
    "#{method}\n#{URI.encode(path)}\n#{URI.encode_query(query_params)}\n#{canonical_headers(headers)}"
    |> Kernel.<>("\n\n#{signed_headers(headers)}\n#{payload}")
    |> hash()
    |> hex_encode()
  end

  defp canonical_headers(headers) do
    headers |> Enum.sort() |> Enum.map(&canonical_header/1) |> Enum.join("\n")
  end

  defp canonical_header({key, value}), do: "#{String.trim(String.downcase(key))}:#{String.trim(value)}"

  defp signed_headers(headers) do
    headers |> Enum.sort() |> Enum.map(&signed_header/1) |> Enum.join(";")
  end

  defp signed_header({key, _}), do: String.downcase(key) |> String.trim()

  def string_to_sign(datetime, scope, hashed_request) do
    Enum.join(["AWS4-HMAC-SHA256", datetime, scope, hashed_request], "\n")
  end

  def credential_scope(datetime, region, service), do: "#{short_date(datetime)}/#{region}/#{service}/aws4_request"

  def calc_signing_key(secret_key, datetime, region, service) do
    "AWS4#{secret_key}" |> hmac(short_date(datetime)) |> hmac(region) |> hmac(service) |> hmac("aws4_request")
  end

  def calc_signature(key, string_to_sign), do: hmac(key, string_to_sign) |> hex_encode()

  def authorization_header(access_key, scope, headers, signature) do
    [
      "AWS4-HMAC-SHA256 Credential=#{access_key}/#{scope}",
      "SignedHeaders=#{signed_headers(headers)}",
      "Signature=#{signature}"
    ]
    |> Enum.join(",")
  end
end
