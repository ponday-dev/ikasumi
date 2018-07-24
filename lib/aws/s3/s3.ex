defmodule AWS.S3 do
  def get_object_acl(client, bucket, object) do
    request = %AWS.Request{
      service: "s3",
      host: "#{bucket}.s3.#{client.endpoint}",
      path: object,
      method: :get,
      query_params: [
        {"acl", ""}
      ],
      payload: "",
    }
    AWS.request(client, request, [timeout: :infinity, recv_timeout: :infinity])
  end
end
