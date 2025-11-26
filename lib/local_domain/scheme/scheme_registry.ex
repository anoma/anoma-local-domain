defmodule Anoma.LocalDomain.SchemeRegistry do
  use GenServer
  use TypedStruct

  typedstruct do
    field(:scheme, any(), default: Map.new())
    field(:store, any(), default: Map.new())
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start with a standard environment

    natives = %{
      >: {:native, :erlang, :>},
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
        scheme: natives,
        store: %{}
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
    GenServer.call(__MODULE__, {:all_scheme})
  end

  @impl true
  def handle_cast(
    {:put_scheme, name_scheme, args_scheme, body_scheme},
    state
  ) do
    cell_id = Base.encode16(:crypto.strong_rand_bytes(8))
    env = Map.put(state.scheme, name_scheme, {:cell, cell_id})
    
    {:noreply,
     %__MODULE__{
       state
       |
       scheme: env,
       store:
       Map.put(state.store,
         cell_id,
         {:closure, args_scheme, body_scheme, env})
     }}
  end
      
  @impl true
  def handle_call({:get_scheme, name_scheme}, _from, state) do
    body = Map.get(state.scheme, name_scheme)
    {:reply, {:ok, body}, state}
  end

  @impl true
  def handle_call({:all_scheme}, _from, state) do
    {:reply, {:ok, state.scheme, state.store}, state}
  end
end
