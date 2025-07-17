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
  """
  defmacro sigil_k({:<<>>, _meta, [string]}, _opts) do
    {key, rest} =
      string
      |> String.split("/", trim: true)
      |>sigil_k_segment([])

    # Sadly unquote_splicing/1 requires a proper list
    if rest do
      quote do: [unquote_splicing(key) | unquote(rest)]
    else
      quote do: [unquote_splicing(key)]
    end
  end

  # todo: currently no handling for string interpolation 
  defp sigil_k_segment([], acc) do
    {Enum.reverse(acc), nil}
  end
  
  defp sigil_k_segment([("!" <> var)|rest], acc) do
    # todo: for patterns, maybe not to_existing_atom?
    sigil_k_segment(rest, [{String.to_existing_atom(var), [], nil}|acc])
  end

  defp sigil_k_segment([("&" <> var)|_], acc) do
    # todo: for patterns, maybe not to_existing_atom?
    {Enum.reverse(acc), {String.to_existing_atom(var), [], nil}}
  end
  
  defp sigil_k_segment([literal|rest], acc) do
    sigil_k_segment(rest, [literal|acc])
  end
end
