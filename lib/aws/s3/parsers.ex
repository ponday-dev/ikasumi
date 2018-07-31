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
