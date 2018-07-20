defmodule AWS.Cognito do
  def get_credentials_for_identity(client, identity_id) do
    request(client, "GetCredentialsForIdentity", %{ IdentityId: identity_id })
  end

  defp request(client, action, input, options \\ []) do
    headers = [{"Content-Type", "application/x-amz-json-1.1"}, {"X-Amz-Target", "AWSCognitoIdentityService.#{action}"}]

    case AWS.request(client, "/", "cognito-identity", action, :post, headers, input, options) do
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
