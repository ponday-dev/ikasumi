defmodule AWS.S3 do
  alias AWS.S3.Parsers
  import AWS.Util, only: [slice_as_binary: 2]

  def get_object_acl(client, bucket, object) do
    # x-amz-content-sha256ヘッダの値は空文字をSHA256でハッシュ化して16進数化したもの
    request = %AWS.Request{
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

    request |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def download(client, bucket, object, range \\ nil) do
    headers =
      case range do
        {begin, len} ->
          [{"range", "bytes=#{begin}-#{begin + len - 1}"}]
        _ ->
          []
      end
    %AWS.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: object,
      method: :get,
      headers: headers,
      payload: ""
    }
    |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def upload(client, mode, src, bucket, object, options \\ []) do
    get_stream(src, mode, options[:chunk_size] || 5 * 1024 * 1024) |> upload_stream(client, bucket, object)
  end

  defp upload_stream(enumerable, client, bucket, object) do
    with {:ok, %{body: %{upload_id: upload_id}}} <- initiate_multipart_upload(client, bucket, object) do
      enumerable
      |> Stream.with_index(1)
      |> Task.async_stream(AWS.S3, :upload_part, [client, upload_id, bucket, object])
      |> Enum.to_list()
      |> Enum.map(fn {:ok, val} -> val end)
      |> complete_multipart_upload(client, upload_id, bucket, object)
    end
  end

  def initiate_multipart_upload(client, bucket, object) do
    request = %AWS.Request{
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
    request |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def upload_part({src, index}, client, upload_id, bucket, object) do
    md5_hash = :crypto.hash(:md5, src) |> Base.encode64()
    request = %AWS.Request{
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


    response = request |> AWS.request!(client, [timeout: :infinity, recv_timeout: :infinity])

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

    request = %AWS.Request{
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

    request |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  defp get_stream(path, :file, chunk_size), do: File.stream!(path, [], chunk_size)
  defp get_stream(text, :text, chunk_size), do: slice_as_binary(text, chunk_size)
end
