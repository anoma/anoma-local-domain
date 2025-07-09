defmodule Anoma.LocalDomain do
  @moduledoc """
  I contain universal local domain functionality.
  """

  defmacro __using__(_opts) do
    quote do
      import Anoma.LocalDomain
    end
  end

  @doc """
  I provide the `~k` sigil for entering keys. Key segments are separated with
  `/`, and a key segment may be prefixed with `!` to splice in the value of a
  variable. `!` segments may also be used to match a single segment in a
  pattern.

  # Examples

      iex> use Anoma.LocalDomain
      Anoma.LocalDomain
      iex> c = "segment c"
      "segment c"
      iex> ~k"/a/b/!c/d"
      ["a", "b", "segment c", "d"]
      iex> ~k"/a/b/!c" = ["a", "b", "matched c"]
      ["a", "b", "matched c"]
      iex> c
      "matched c"
  """
  defmacro sigil_k({:<<>>, _meta, [string]}, _opts) do
    key =
      string
      |> String.split("/", trim: true)
      |> Enum.map(&sigil_k_segment/1)

    quote do: [unquote_splicing(key)]
  end

  defp sigil_k_segment("!" <> var) do
    # todo: for patterns, maybe not to_existing_atom?
    {String.to_existing_atom(var), [], nil}
  end

  defp sigil_k_segment(literal) do
    literal
  end
end
