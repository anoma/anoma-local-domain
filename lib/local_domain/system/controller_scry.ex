defmodule Anoma.LocalDomain.System.ControllerScry do
  @moduledoc """
  I define the controller scry application for the local domain.
  """

  # we provide a dummy name, but this is the lone special application which
  # does not use a local keyspace; it works with /anoma/controller.
  use Anoma.LocalDomain.Application, name: "controller_scry"
end
