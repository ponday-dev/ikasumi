defmodule AWS.Client do
  defstruct [
    :access_key,
    :secret_access_key,
    :region,
    :endpoint,
    proto: "https",
    port: 443,
    credential: nil
  ]
end
