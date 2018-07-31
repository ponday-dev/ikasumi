defmodule AWS.S3 do
  alias AWS.S3.Parsers

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

  def upload(client, filepath, bucket, object) do
    with {:ok, %{body: %{upload_id: upload_id}}} <- initiate_multipart_upload(client, bucket, object) do
      file_stream(filepath)
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
    }

    request |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def file_stream(path, options \\ []), do: File.stream!(path, [], options[:chunk_size] || 5 * 1024 * 1024)
end

defmodule AWS.S3.Parsers do
  import SweetXml, only: [sigil_x: 2]
  def parse_object_acl(response) do
    body = response.body |> SweetXml.xpath(~x"//AccessControlPolicy",
      owner: [
        ~x"./Owner",
        id: ~x"./ID/text()"s,
        name: ~x"./DisplayName/text()"s
      ],
      acl: [
        ~x"./AccessControlList",
        grant: [
          ~x"./Grant/Grantee"l,
          id: ~x"./ID/text()"s,
          name: ~x"./DisplayName/text()"s
        ]
      ]
    )
    %{response | body: body}
  end

  def parse_initiate_multipart_upload(response) do
    body = response.body |> SweetXml.xpath(~x"//InitiateMultipartUploadResult",
      bucket: ~x"./Bucket/text()"s,
      key: ~x"./Key/text()"s,
      upload_id: ~x"./UploadId/text()"s
    )
    %{response | body: body}
  end
end
