defmodule Ikasumi.Client do
  defstruct [
    :access_key,
    :secret_access_key,
    :region,
    :endpoint,
    proto: "https",
    port: 443,
    credentials: nil,
    identity_pool_id: "",
    user_pool_id: "",
    account_id: ""
  ]
end
