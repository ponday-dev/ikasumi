defmodule AWS.Request do
  alias AWS.Client
  alias AWS.Request.Internal
  import AWS.Util, only: [timestamp: 0]

  def sign_v4(%Client{} = client, method, path, query_params, headers, payload) do
    sign_v4(client, timestamp(),method, path, query_params, headers, payload)
  end
  def sign_v4(%Client{} = client, datetime, method, path, query_params, headers, payload) do
    headers = [{ "X-Amz-Date", datetime } | headers]
    request = Internal.hash_canonical_request(method, path, query_params, headers, payload)
    credential_scope = Internal.credential_scope(datetime, client.region, client.service)

    signing_key = Internal.calc_signing_key(client.secret_access_key, datetime, client.region, client.service)
    string_to_sign = Internal.string_to_sign(datetime, credential_scope, request)
    signature = Internal.calc_signature(signing_key, string_to_sign)
    authorization = Internal.authorization_header(client.access_key, credential_scope, headers, signature)

    [{ "Authorization", authorization } | headers]
  end
end

defmodule AWS.Request.Internal do
  alias AWS.Client
  import AWS.Util

  def hash_canonical_request(method, path, query_params, headers, payload) when is_atom(method) do
    Atom.to_string(method)
    |> String.upcase()
    |> hash_canonical_request(path, query_params, headers, payload)
  end

  def hash_canonical_request(method, path, query_params, headers, payload) do
    [
      method, canonical_uri(path), canonical_query_string(query_params),
      canonical_headers(headers), signed_headers(headers), hex_encode(hash(payload))
    ]
    |> Enum.join("\n")
    |> hash()
    |> hex_encode()
  end

  defp canonical_uri(uri), do: URI.encode(uri, &(&1 in unescaped_chars()))

  defp canonical_query_string(query_params), do: URI.encode_query(query_params)

  defp unescaped_chars, do: Enum.concat([?a .. ?z, ?A .. ?Z, ?0 .. ?9, [ ?-, ?_, ?., ?~]])

  def canonical_headers(headers) do
    headers |> Enum.sort() |> Enum.map(&canonical_header/1) |> Enum.join("\n")
  end

  defp canonical_header({key, value}), do: "#{String.trim(String.downcase(key))}:#{String.trim(value)}"

  def signed_headers(headers) do
    headers |> Enum.sort() |> Enum.map(&signed_header/1) |> Enum.join(";")
  end

  def signed_header({key, _}), do: String.downcase(key) |> String.trim()

  def string_to_sign(datetime, scope, hashed_request) do
    Enum.join(["AWS4-HMAC-SHA256", datetime, scope, hashed_request], "\n")
  end

  def credential_scope(date, region, service), do: "#{short_date(date)}/#{region}/#{service}/aws4_request"

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
    |> Enum.join(", ")
  end
end
