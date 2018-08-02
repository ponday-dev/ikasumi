defmodule AWSTest do
  use ExUnit.Case
  doctest AWS

  describe "AWS.Request.Signer.sign_v4/2" do
    test "Hashed payload" do
      assert s3_test_data().hashed_payload == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
    test "Hashed request" do
      assert s3_test_data().hashed_request == "9766c798316ff2757b517bc739a67f6213b4ab36dd5da2f94eaebf79c77395ca"
    end
    test "Signature" do
      assert s3_test_data().signature == "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543"
    end
  end

  defp s3_test_client do
    %AWS.Client{
      access_key: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      endpoint: "amazonaws.com"
    }
  end
  defp s3_test_request do
    %AWS.Request{
      service: "s3",
      host: "examplebucket.s3.amazonaws.com",
      path: "/",
      method: :get,
      query_params: [
        {"lifecycle", ""}
      ],
      payload: ""
    }
  end
  defp s3_test_data do
    client = s3_test_client()
    request = s3_test_request()
    AWS.Request.Signer.sign_v4(request, client, ~D[2013-05-24], [])
  end
end
