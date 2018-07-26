defmodule AWS.S3 do
  alias AWS.S3.Parsers

  def get_object_acl(client, bucket, object) do
    # x-amz-content-sha256ヘッダの値は空文字をSHA256でハッシュ化して16進数化したもの
    request = %AWS.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: object,
      method: :get,
      headers: [
        {"x-amz-content-sha256", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}
      ],
      query_params: [
        {"acl", ""}
      ],
      payload: "",
      parser: &Parsers.parse_object_acl/1
    }

    request
    |> AWS.sign_v4(client, hashed: true)
    |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  def upload(client, filepath, bucket, object) do
    with {:ok, %{body: %{upload_id: upload_id}}} <- initiate_multipart_upload(client, bucket, object) do
      # seed_request = %AWS.Request{
      #   service: "s3",
      #   host: "#{bucket}.s3.#{client.endpoint}",
      #   path: "/#{object}",
      #   method: :post,
      #   headers: [
      #     {"content-encoding", "aws-chunked"},
      #     {"content-length", md5_hash |> byte_size() |> to_string() },
      #     {"x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD"}
      #     # {"x-amz-decoded-content-length", to_string( 5 * 1024 * 1024)},
      #     {"x-amz-storage-class", "REDUCED_REDUNDANCY"}
      #   ],
      #   query_params: [
      #     {"partNumber", to_string(index)},
      #     {"uploadId", upload_id}
      #   ],
      #   payload: "STREAMING-AWS4-HMAC-SHA256-PAYLOAD",
      # }
      # {seed, _} = AWS.sign_v4
      # file_stream(filepath)
      # |> Stream.with_index(1)
      # |> complete_multipart_upload(client, upload_id, bucket, object)
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
      headers: [
        {"x-amz-content-sha256", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}
      ],
      query_params: [
        {"uploads", ""}
      ],
      payload: "",
      parser: &Parsers.parse_initiate_multipart_upload/1
    }
    request
    |> AWS.sign_v4(client, [hashed: true])
    |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
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
        {"content-md5", md5_hash },
        # {"x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD"},
        {"x-amz-content-sha256", src |> AWS.Util.hash() |> AWS.Util.hex_encode()},
        {"x-amz-decoded-content-length", to_string( 5 * 1024 * 1024)}
        # {"x-amz-storage-class", "REDUCED_REDUNDANCY"}
      ],
      query_params: [
        {"partNumber", to_string(index)},
        {"uploadId", upload_id}
      ],
      # payload: "STREAMING-AWS4-HMAC-SHA256-PAYLOAD",
      payload: src,
    }
    response = request
    |> AWS.sign_v4(client, hashed: true)
    |> AWS.request!(client, [timeout: :infinity, recv_timeout: :infinity])
    response |> inspect |> IO.puts
    {_, etag} = Enum.find(response.headers, fn {key, _} -> String.downcase(key) == "etag" end)
    {etag, index}
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
      path: "/#{object}",
      method: :post,
      headers: [
        {"content-length", payload |> byte_size() |> to_string() }
      ],
      query_params: [
        {"uploadId", upload_id}
      ],
      payload: payload,
    }

    request
    |> AWS.sign_v4(client)
    |> AWS.request(client, [timeout: :infinity, recv_timeout: :infinity])
  end

  # def post_object(client, filepath, bucket, object) do
  #   req = %{
  #     src: file_stream(filepath),
  #     bucket: bucket,
  #     path: object,
  #     upload_id: nil
  #   }

  #   headers = [
  #     {"cache-control", ""},
  #     {"content-disposition", ""},
  #     {"content-encoding", ""},
  #     {"content-length", ""},
  #     {"content-type", ""},
  #     {"expect", ""},
  #     {"expires", ""},
  #     {"content-md5", ""},
  #     {"x-amz-storage-class", ""},
  #     {"x-amz-website-redirect-location", ""},
  #     {"x-amz-tagging", ""},
  #     {"x-amz-acl", ""}
  #     # {"x-amz-server-side-encryption", ""},
  #     # {"x-amz-server-side-encryption-*", ""},
  #     # {"x-amz-meta-*", ""}
  #   ]

  #   request = %AWS.Request{
  #     service: "s3",
  #     host: "#{bucket}.s3.#{client.endpoint}",
  #     path: object,
  #     body: "",
  #     headers: headers,
  #   }

  #   file_stream(path)
  #   |> Stream.with_index(1)
  #   |> Task.async_stream(S3, :upload_chunk!, [request], [])
  #   |> Enum.to_list()
  #   |> Enum.map(fn {:ok, val} -> val end)
  # end

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
    response |> inspect() |> IO.puts
    body = response.body |> SweetXml.xpath(~x"//InitiateMultipartUploadResult",
      bucket: ~x"./Bucket/text()"s,
      key: ~x"./Key/text()"s,
      upload_id: ~x"./UploadId/text()"s
    )
    %{response | body: body}
  end
end
