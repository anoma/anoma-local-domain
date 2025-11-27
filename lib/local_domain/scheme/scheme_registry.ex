defmodule Anoma.LocalDomain.SchemeRegistry do
  use GenServer
  use TypedStruct

  typedstruct do
    field(:scheme, any(), default: Anoma.LocalDomain.Scheme.new_env())
    field(:prelude, any(), default: [])
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start with a standard environment

    natives = %{
      +: {:native, :erlang, :+},
      -: {:native, :erlang, :-},
      ==: {:native, :erlang, :==},
      get: {:native, Map, :get},
      put: {:native, Map, :put},
      not: {:native, :erlang, :not},
      is_integer: {:native, :erlang, :is_integer},
      is_number: {:native, :erlang, :is_number}
    }

    std =
      %__MODULE__{
        scheme: Anoma.LocalDomain.Scheme.map_to_env(natives)
      }

    {:ok, std}
  end

  @doc """
  Register all elixir->scheme mappings in a process.
  Why a process? Because we also need to do this for modules we don't control.
  """
  def register(module) do
    for {name_scheme, args_scheme, body_scheme} <-
          module.__scheme_fns__() do
      put_scheme(
        name_scheme,
        args_scheme,
        body_scheme
      )
    end

    :ok
  end

  def put_scheme(name_scheme, args_scheme, body_scheme) do
    GenServer.cast(
      __MODULE__,
      {:put_scheme, name_scheme, args_scheme, body_scheme}
    )
  end

  def get_scheme(name_scheme) do
    case GenServer.call(__MODULE__, {:get_scheme, name_scheme}) do
      {:ok, body} -> body
    end
  end

  def all_scheme() do
    {:ok, {scheme_fns, prelude_fns}} = GenServer.call(__MODULE__, {:all_scheme})

    {:ok, {scheme_fns, prelude_fns}}
  end

  @impl true
  def handle_cast(
        {:put_scheme, name_scheme, args_scheme, body_scheme},
        state
      ) do
    func = [:function, name_scheme, args_scheme, body_scheme]
    {:noreply, %__MODULE__{state | prelude: [func | state.prelude]}}
  end

  @impl true
  def handle_call({:get_scheme, name_scheme}, _from, state) do
    body = Anoma.LocalDomain.Scheme.get_env(state.scheme, name_scheme)
    {:reply, {:ok, body}, state}
  end

  @impl true
  def handle_call({:all_scheme}, _from, state) do
    {:reply, {:ok, {state.scheme, state.prelude}}, state}
  end
end
