defmodule AWS.Client do
  defstruct [:access_key, :secret_access_key, :region, :endpoint, service: "", proto: "https", port: 443]

  def from_env do
    %AWS.Client {
      access_key: Application.get_env(:aws_ex, :access_key),
      secret_access_key: Application.get_env(:aws_ex, :secret_access_key),
      region: Application.get_env(:aws_ex, :region),
      endpoint: Application.get_env(:aws_ex, :endpoint)
    }
  end
end
