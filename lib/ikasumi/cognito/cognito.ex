defmodule Ikasumi.Cognito do
  def get_credentials_for_identity(client, identity_id) do
    request(client, "/", "GetCredentialsForIdentity", %{ IdentityId: identity_id }) |> send_request(client)
  end
  def get_credentials_for_identity(client, id_provider, identity_id, id_token) do
    payload = %{
      "IdentityId" => identity_id,
      "Logins" => %{
        provider(client, id_provider) => id_token
      }
    }
    request(client, "/", "GetCredentialsForIdentity", payload) |> send_request(client)
  end

  def get_id(client, id_provider, token) do
    payload = %{
      "IdentityPoolId" => client.identity_pool_id,
      "Logins" => %{
        provider(client, id_provider) => token
      }
    }
    |> (fn body -> if %{account_id: ""} = client, do: body, else: %{body | "AccountId" => client.account_id} end).()

    request(client, "/", "GetId", payload) |> send_request(client)
  end

  defp provider(_, :google), do: "accounts.google.com"
  defp provider(client, :cognito_user_pool), do: "cognito-idp.#{client.region}.amazonaws.com/#{client.user_pool_id}"
  defp provider(_, :facebook), do: "graph.facebook.com"
  defp provider(_, :twitter), do: "api.twitter.com"
  defp provider(_, name), do: name

  defp request(client, path, action, payload) do
    %Ikasumi.Request{
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
    case Ikasumi.request(request, client, options) do
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
