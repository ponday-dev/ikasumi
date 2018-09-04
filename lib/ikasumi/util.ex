defmodule Ikasumi.Util do
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
