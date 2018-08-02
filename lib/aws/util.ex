defmodule AWS.Util do
  def hash(value), do: :crypto.hash(:sha256, value)
  def hmac(secret, value), do: :crypto.hmac(:sha256, secret, value)
  def hex_encode(value), do: Base.encode16(value, case: :lower)

  def to_amz_datetime(datetime), do: Timex.format!(datetime, "{YYYY}{0M}{0D}T{h24}{0m}{0s}Z")
  def short_date(datetime), do: String.slice(datetime, 0..7)

  def identity(i), do: i

  def slice_as_binary("", _), do: []
  def slice_as_binary(binary, chunk_size) when byte_size(binary) < chunk_size, do: [binary]
  def slice_as_binary(binary, chunk_size), do: slice_as_binary(binary, byte_size(binary), 0, chunk_size)

  def slice_as_binary(_, size, start, _) when size == start, do: []
  def slice_as_binary(binary, size, start, chunk_size) when (size - start) < chunk_size do
    [binary_part(binary, start, size - start)]
  end
  def slice_as_binary(binary, size, start, chunk_size) do
    [binary_part(binary, start, chunk_size) | slice_as_binary(binary, size, start + chunk_size, chunk_size)]
  end
end
