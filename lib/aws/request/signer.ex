defmodule AWS.Request.Signer do
  alias AWS.{Client, Request}
  alias AWS.Request.Signer.Internal

  def sign_v4(%Request{} = request, %Client{} = client, options \\ []), do: sign_v4(request, client, Timex.now(), options)
  def sign_v4(%Request{} = request, %Client{} = client, datetime, options) do
    request
    |> Internal.put_amz_datetime(datetime)
    |> Internal.put_hashed_payload()
    |> Internal.put_headers()
    |> Internal.put_sha256_header()
    |> Internal.put_security_header(client)
    |> Internal.hash_request()
    |> Internal.calc_credential_scope(client)
    |> Internal.calc_string_to_sign()
    |> Internal.calc_signing_key(client)
    |> Internal.calc_signature()
    |> Internal.put_authorization_header(client)
  end
end

defmodule AWS.Request.Signer.Internal do
  alias AWS.{Client, Request}
  import AWS.Util, only: [to_amz_datetime: 1, hash: 1, hmac: 2, hex_encode: 1, short_date: 1]

  def put_amz_datetime(%Request{} = request, datetime), do: %{request | datetime: to_amz_datetime(datetime)}

  def put_hashed_payload(%Request{payload: nil} = request), do: do_put_hashed_hashed_payload(%{request | payload: ""})
  def put_hashed_payload(%Request{} = request), do: do_put_hashed_payload(request)

  defp do_put_hashed_payload(%Request{} = request), do: %{request | hashed_payload: request.payload |> hash() |> hex_encode()}

  def put_headers(%Request{} = request) do
    %{request | headers: [{"host", request.host}, {"x-amz-date", request.datetime}]}
  end

  def put_sha256_header(%Request{service: "s3"} = request) do
    %{request | headers: [{"x-amz-content-sha256", request.hashed_payload} | request.headers]}
  end
  def put_sha256_header(%Request{} = request), do: request

  def put_security_header(%Request{} = request, %Client{credentials: nil}), do: request
  def put_security_header(%Request{} = request, %Client{ credentials: credentials}) do
    %{request | headers: [{"x-amz-security-token", Map.get(credentials, "SessionToken")} | request.headers]}
  end

  def hash_request(%Request{method: method} = request) when is_atom(method),
    do: hash_request(%{request | method: Atom.to_string(method), else: method) |> String.upcase()})
  def hash_request(%Request{} = request), do: %{request | hashed_request: do_hash_request(request)}
  defp do_hash_request(%Request{} = request) do
    [
      request.method, "\n",
      URI.encode(request.path), "\n",
      canonical_headers(request.headers), "\n\n",
      signed_headers(headers), "\n",
      request.hashed_payload
    ]
    |> Enum.join("")
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

  def calc_credential_scope(%Request{} = request, %Client{} = client) do
    %{request | credential_scope: do_calc_credential_scope(request, client)}
  end
  defp do_calc_redential_scope(%Request{} = request, %Client{region: region}) do
    [
      short_date(request.datetime),
      region,
      request.service,
      "aws4_request"
    ]
    |> Enum.join("/")
  end

  def calc_string_to_sign(%Request{} = request), do: %{request | calc_string_to_sign: do_string_to_sign(request)}
  defp do_calc_string_to_sign(%Request{} = request) do
    [
      "AWS4-HMAC-SHA256",
      request.datetime,
      request.credential_scope,
      request.hashed_request
    ]
    |> Enum.join("\n")
  end

  def calc_signing_key(%Request{} = request, %Client{} = client) do
    %{request | signing_key: do_calc_signing_key(request, client)}
  end
  defp do_calc_signing_key(%Request{} = request, %Client{} = client) do
    "AWS4"
    |> Kernel.<>(client.secret_access_key)
    |> hmac(short_date(request.datetime))
    |> hmac(client.region)
    |> hmac(request.service)
    |> hmac("aws4_request")
  end

  def calc_signature(%Request{} = request), do: hmac(request.signing_key, request.string_to_sign) |> hex_encode()

  def put_authorization_header(%Request{} = request, %Client{} = client) do
    [
      "AWS4-HMAC-SHA256 Credential=#{client.access_key}/#{request.credential_scope}",
      "SignedHeaders=#{signed_headers(request.headers)}",
      "Signature=#{request.signature}"
    ]
    |> Enum.join(",")
  end
end
