defmodule Anoma.LocalDomain.Views do

  use TypedStruct
  use GtBridge.View

  alias GtBridge.Phlow.Text

  @gt_views{Atom, {__MODULE__, :node_supervisor_view}}
  def node_supervisor_view(on_pid, builder) do
    builder.text()
    |> Text.priority(1)
    |> Text.title("TEST")
    |> Text.string(fn -> "Name" end)
  end
end
