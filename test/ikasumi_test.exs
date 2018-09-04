defmodule IkasumiTest do
  use ExUnit.Case
  doctest Ikasumi

  describe "Ikasumi.Request.Signer.sign_v4/2" do
    test "Signature" do
      signature =
        s3_test_data().headers
        |> Enum.find(fn {key, _} -> key == "Authorization" end)
        |> elem(1)
        |> String.split(",")
        |> Enum.reverse()
        |> hd()
      assert signature == "Signature=fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543"
    end
  end

  defp s3_test_client do
    %Ikasumi.Client{
      access_key: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      endpoint: "amazonaws.com"
    }
  end
  defp s3_test_request do
    %Ikasumi.Request{
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
    Ikasumi.Request.Signer.sign_v4(request, client, ~D[2013-05-24], [])
  end
end
