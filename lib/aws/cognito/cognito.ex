defmodule AWS.Cognito do
  def get_credentials_for_identity(client, identity_id) do
    request(client, "/", "GetCredentialsForIdentity", %{ IdentityId: identity_id }) |> send_request(client)
  end

  defp request(client, path, action, payload) do
    %AWS.Request{
      service: "cognito-identity",
      host: "cognito-identity.#{client.region}.#{client.endpoint}",
      path: path,
      method: :post,
      headers: [
        {"Content-Type", "application/x-amz-json-1.1"},
        {"X-Amz-Target", "AWSCognitoIdentityService.#{action}"}
      ],
      payload: payload
    }
  end

  defp send_request(request, client, options \\ []) do
    case AWS.request(client, request, options) do
      {:ok, response=%HTTPoison.Response{status_code: 200, body: ""}} ->
        {:ok, nil, response}
      {:ok, response=%HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.Parser.parse!(body), response}
      {:ok, _response=%HTTPoison.Response{body: body}} ->
        error = Poison.Parser.parse!(body)
        exception = error["__type"]
        message = error["message"]
        {:error, {exception, message}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end
end
