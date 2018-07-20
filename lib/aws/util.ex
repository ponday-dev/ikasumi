defmodule AWS.Util do
  def hash(value), do: :crypto.hash(:sha256, value)
  def hmac(secret, value), do: :crypto.hmac(:sha256, secret, value)
  def hex_encode(value), do: Base.encode16(value, case: :lower)
  def timestamp, do: Timex.format!(Timex.now(), "{YYYY}{0M}{D}T{h24}{0m}{0s}Z")

  def short_date(datetime), do: String.slice(datetime, 0..7)
end
