defmodule Ikasumi.Cognito do
  def get_credentials_for_identity(client, identity_id) do
    request(client, "/", "GetCredentialsForIdentity", %{ IdentityId: identity_id }) |> Ikasumi.request(client)
  end
  def get_credentials_for_identity(client, id_provider, identity_id, id_token) do
    payload = %{
      "IdentityId" => identity_id,
      "Logins" => %{
        provider(client, id_provider) => id_token
      }
    }

    request(client, "/", "GetCredentialsForIdentity", payload) |> Ikasumi.request(client)
  end

  def get_id(client, id_provider, token) do
    payload = %{
      "IdentityPoolId" => client.identity_pool_id,
      "Logins" => %{
        provider(client, id_provider) => token
      }
    }
    |> get_id_(client)

    request(client, "/", "GetId", payload) |> Ikasumi.request(client)
  end
  defp get_id_(payload, %{account_id: ""}), do: payload
  defp get_id_(payload, %{account_id: account_id}), do: Map.put(payload, "AccountId", account_id)

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

end
