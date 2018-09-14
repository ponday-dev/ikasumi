defmodule Ikasumi.Request.Signer do
  alias Ikasumi.{Client, Request}
  alias Ikasumi.Request.Signer.Internal

  def sign_v4(%Request{} = request, %Client{} = client, options \\ []), do: sign_v4(request, client, Timex.now(), options)
  def sign_v4(%Request{} = request, %Client{} = client, datetime, _) do
    with {:ok, amz_datetime} <- Internal.amz_datetime(datetime) do

      amz_date = Internal.amz_date(amz_datetime)
      payload = Internal.hash_payload(request.payload)
      headers = build_headers(request, client, amz_datetime, payload)
      canonical_headers = Internal.canonical_headers(headers)
      signed_headers = Internal.signed_headers(headers)

      hashed_request = hash_request(request, canonical_headers, signed_headers, payload)
      credential_scope = Internal.credential_scope(amz_date, client.region, request.service)
      string_to_sign = Internal.string_to_sign(amz_datetime, credential_scope, hashed_request)
      signing_key = Internal.signing_key(client.secret_access_key, amz_date, client.region, request.service)
      signature = Internal.signature(signing_key, string_to_sign)

      %{request | headers: put_authorization_header(headers, client.access_key, credential_scope, signed_headers, signature)}
    end
  end

  defp build_headers(%Request{} = request, %Client{credentials: credentials}, datetime, payload) do
    request.headers
    |> put_host_header(request.host)
    |> put_amz_date_header(datetime)
    |> put_sha256_header(request.service, payload)
    |> put_security_header(credentials)
  end

  defp put_host_header(headers, host), do: [Internal.host_header(host) | headers]

  defp put_amz_date_header(headers, datetime), do: [Internal.amz_date_header(datetime) | headers]

  defp put_sha256_header(headers, "s3", payload), do: [Internal.sha256_header(payload) | headers]
  defp put_sha256_header(headers, _, _), do: headers

  defp put_security_header(headers, nil), do: headers
  defp put_security_header(headers, credentials), do: [Internal.security_header(credentials) | headers]

  defp hash_request(%Request{method: method} = request, canonical_headers, signed_headers, payload) when is_atom(method),
    do: hash_request(%{request | method: Atom.to_string(method)}, canonical_headers, signed_headers, payload)
  defp hash_request(%Request{method: method, path: path, query_params: qparams}, canonical_headers, signed_headers, payload),
    do: Internal.hash_request(String.upcase(method), path, qparams, canonical_headers, signed_headers, payload)

  defp put_authorization_header(headers, access_key, credential_scope, signed_headers, signature) do
    [Internal.authorization_header(access_key, credential_scope, signed_headers, signature) | headers]
  end
end

defmodule Ikasumi.Request.Signer.Internal do

  def amz_datetime(datetime), do: Timex.format(datetime, "{YYYY}{0M}{0D}T{h24}{0m}{0s}Z")

  def amz_date(amz_datetime), do: String.slice(amz_datetime, 0..7)

  def hash_payload(nil) do
    hash_payload("")
  end

  def hash_payload(%{} = body) do
    with {:ok, str_body} <- Poison.encode(body), do: hash_payload(str_body)
  end

  def hash_payload(body), do: body |> hash() |> hex()

  def host_header(host), do: {"host", host}

  def amz_date_header(datetime), do: {"x-amz-date", datetime}

  def sha256_header(payload), do: {"x-amz-content-sha256", payload}

  def security_header(credentials), do: {"x-amz-security-token", Map.get(credentials, "SessionToken")}

  def hash_request(method, path, query_params, canonical_headers, signed_headers, hashed_payload) do
    [
      method, "\n",
      URI.encode(path), "\n",
      URI.encode_query(query_params), "\n",
      canonical_headers, "\n\n",
      signed_headers, "\n",
      hashed_payload
    ]
    |> Enum.join("")
    |> hash()
    |> hex()
  end

  def canonical_headers(headers), do: headers |> Enum.sort() |> Enum.map(&canonical_header/1) |> Enum.join("\n")

  def canonical_header({key, value}), do: "#{String.trim(String.downcase(key))}:#{String.trim(value)}"

  def signed_headers(headers), do: headers |> Enum.sort() |> Enum.map(&signed_header/1) |> Enum.join(";")

  def signed_header({key, _}), do: String.downcase(key) |> String.trim()

  def credential_scope(date, region, service), do: "#{date}/#{region}/#{service}/aws4_request"

  def string_to_sign(datetime, credential_scope, hashed_request) do
    "AWS4-HMAC-SHA256\n#{datetime}\n#{credential_scope}\n#{hashed_request}"
  end

  def signing_key(secret_key, date, region, service) do
    "AWS4#{secret_key}"
    |> hmac(date)
    |> hmac(region)
    |> hmac(service)
    |> hmac("aws4_request")
  end

  def signature(signing_key, string_to_sign), do: hmac(signing_key, string_to_sign) |> hex()

  def authorization_header(access_key, credential_scope, signed_headers, signature) do
    {"Authorization", "AWS4-HMAC-SHA256 Credential=#{access_key}/#{credential_scope},SignedHeaders=#{signed_headers},Signature=#{signature}"}
  end

  def hash(value) when is_binary(value), do: :crypto.hash(:sha256, value)

  def hmac(secret, value) when is_binary(secret) and is_binary(value), do: :crypto.hmac(:sha256, secret, value)

  def hex(v) when is_binary(v), do: Base.encode16(v, case: :lower)
end
