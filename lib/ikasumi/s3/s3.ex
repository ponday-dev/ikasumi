defmodule Ikasumi.S3 do
  alias Ikasumi.S3.Parsers
  import Ikasumi.Util, only: [slice_as_binary: 2]

  def get_object_acl(client, bucket, object) do
    # x-amz-content-sha256ヘッダの値は空文字をSHA256でハッシュ化して16進数化したもの
    request = %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: object,
      method: :get,
      query_params: [
        {"acl", ""}
      ],
      payload: "",
      parser: &Parsers.parse_object_acl/1
    }

    request |> Ikasumi.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def download(client, bucket, object, range \\ nil) do
    headers =
      case range do
        {begin, len} ->
          [{"range", "bytes=#{begin}-#{begin + len - 1}"}]
        _ ->
          []
      end
    %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: object,
      method: :get,
      headers: headers,
      payload: ""
    }
    |> Ikasumi.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  @doc """
  # S3 file upload.
    When the same name object exists, this function will work as update action.

  ## Parameters
    - client: The authenticated Ikasumi.Client object.
    - mode: Source type
      - :file　Upload src as file path string.
      - :binary Upload src as binary.
    - src: Source data
    - bucket: The bucket name of upload target.
    - object: The name of upload object.
    - options: (Optional) Upload options.
      - :chunk_size The chunk size when upload with splitted binaries.(default: 5MB = 5 * 1024 * 1024)

  ## Example
    client
    |> Ikasumi.get_credentials(identity_id)
    |> Ikasumi.S3.upload(:binary, "{\"foo\": 1}", "examplebucket", "example.json")
  """
  def upload(client, mode, src, bucket, object, options \\ []) do
    get_stream(src, mode, options[:chunk_size] || 5 * 1024 * 1024) |> upload_stream(client, bucket, object)
  end

  defp upload_stream(enumerable, client, bucket, object) do
    with {:ok, %{body: %{upload_id: upload_id}}} <- initiate_multipart_upload(client, bucket, object) do
      enumerable
      |> Stream.with_index(1)
      |> Task.async_stream(Ikasumi.S3, :upload_part, [client, upload_id, bucket, object])
      |> Enum.to_list()
      |> Enum.map(fn {:ok, val} -> val end)
      |> complete_multipart_upload(client, upload_id, bucket, object)
    end
  end

  def initiate_multipart_upload(client, bucket, object) do
    request = %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: "#{object}",
      method: :post,
      query_params: [
        {"uploads", ""}
      ],
      payload: "",
      parser: &Parsers.parse_initiate_multipart_upload/1
    }
    request |> Ikasumi.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def upload_part({src, index}, client, upload_id, bucket, object) do
    md5_hash = :crypto.hash(:md5, src) |> Base.encode64()
    request = %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: "#{object}",
      method: :put,
      headers: [
        {"content-encoding", "aws-chunked"},
        {"content-length", src|> byte_size() |> to_string() },
        {"content-md5", md5_hash }
      ],
      query_params: [
        {"partNumber", to_string(index)},
        {"uploadId", upload_id}
      ],
      payload: src
    }


    response = request |> Ikasumi.request!(client, [timeout: :infinity, recv_timeout: :infinity])

    {_, etag} = Enum.find(response.headers, fn {key, _} -> String.downcase(key) == "etag" end)
    {String.slice(etag, 1..-2), index}
  end

  def complete_multipart_upload(etags, client, upload_id, bucket, object) do
    payload = etags
    |> Enum.map((fn {etag, i} ->
      """
      <Part>
      <PartNumber>#{i}</PartNumber>
      <ETag>#{etag}</ETag>
      </Part>
      """
    end))
    |> Enum.join("\n")
    |> (fn tags -> "<CompleteMultipartUpload>#{tags}</CompleteMultipartUpload>" end).()

    request = %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: "#{object}",
      method: :post,
      headers: [
        {"content-length", payload |> byte_size() |> to_string() }
      ],
      query_params: [
        {"uploadId", upload_id}
      ],
      payload: payload,
      parser: &Parsers.parse_complete_multipart_upload/1
    }

    request |> Ikasumi.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def delete_object(client, bucket, object) do
    %Ikasumi.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: "#{object}",
      method: :delete,
      payload: ""
    }
    |> Ikasumi.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  defp get_stream(path, :file, chunk_size), do: File.stream!(path, [], chunk_size)
  defp get_stream(binary, :binary, chunk_size), do: slice_as_binary(binary, chunk_size)
end
