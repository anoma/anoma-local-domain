defmodule Anoma.LocalDomain.SchemeRegistry do
  use GenServer
  use TypedStruct

  typedstruct do
    field(:elixir, any(), default: Map.new())
    field(:scheme, any(), default: Map.new())
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start with a standard environment
    # Note that if you wanna do something to the args you basically need to manipulate it as part of the :elixir store, E.G., if I want to flip Enum.at(xs, n) to (nth n xs) I should compose nth with a flip

    std =
      %__MODULE__{
        elixir: %{
          :erlang => %{
            +: "+",
            -: "-",
            ==: "==",
            is_number: "number?",
            not: "not",
            length: "length",
            is_integer: "integer?",
            tl: "cdr",
            hd: "car",
            apply: "apply",
            and: "and",
            or: "or"
          },
          Map => %{
            get: "get",
            put: "put"
          },
          Enum => %{
            at: "nth",
            map: "map",
            filter: "filter",
            take: "take"
          }
        },
        scheme: %{
          "+" => {"native", :erlang, :+},
          "-" => {"native", :erlang, :-},
          "==" => {"native", :erlang, :==},
          "number?" => {"native", :erlang, :is_number},
          "get" => {"native", Map, :get},
          "put" => {"native", Map, :put},
          "not" => {"native", :erlang, :not},
          "length" =>
            {"closure", ["xs"],
             [
               "if",
               ["==", "xs", nil],
               0,
               ["+", 1, ["length", ["cdr", "xs"]]]
             ]},
          "integer?" => {"native", :erlang, :is_integer},
          "nth" =>
            {"closure", ["xs", "n"],
             [
               "if",
               ["==", "n", 0],
               ["car", "xs"],
               ["nth", ["cdr", "xs"], ["-", "n", 1]]
             ]},
          "map" =>
            {"closure", ["xs", "f"],
             [
               "if",
               ["==", "xs", nil],
               nil,
               [
                 "cons",
                 ["f", ["car", "xs"]],
                 ["map", ["cdr", "xs"], "f"]
               ]
             ]},
          "filter" =>
            {"closure", ["xs", "f"],
             [
               "if",
               ["==", "xs", nil],
               nil,
               [
                 "if",
                 ["f", ["car", "xs"]],
                 [
                   "cons",
                   ["car", "xs"],
                   ["filter", ["cdr", "xs"], "f"]
                 ],
                 ["filter", ["cdr", "xs"], "f"]
               ]
             ]},
          "nthcdr" =>
            {"closure", ["xs", "n"],
             [
               "if",
               ["==", "n", 0],
               "xs",
               ["nthcdr", ["cdr", "xs"], ["-", "n", 1]]
             ]},
          "take" =>
            {"closure", ["xs", "n"],
             [
               "if",
               ["==", "n", 0],
               nil,
               [
                 "cons",
                 ["car", "xs"],
                 ["take", ["cdr", "xs"], ["-", "n", 1]]
               ]
             ]}
        }
      }

    {:ok, std}
  end

  @doc """
  Register all elixir->scheme mappings in a process.
  Why a process? Because we also need to do this for modules we don't control.
  """
  def register(module) do
    for {module, name, scheme_name, body} <- module.__scheme_fns__() do
      put(
        module,
        name,
        scheme_name,
        body
      )
    end
  end

  def put(module, name, scheme_name, body) do
    GenServer.cast(__MODULE__, {:put, module, name, scheme_name, body})
  end

  def get_elixir(module, name) do
    GenServer.call(__MODULE__, {:get_elixir, module, name})
  end

  def get_scheme(name) do
    GenServer.call(__MODULE__, {:get_scheme, name})
  end

  def all_scheme() do
    GenServer.call(__MODULE__, {:all_scheme})
  end

  @impl true
  def handle_cast({:put, module, name, scheme_name, body}, state) do
    {:noreply,
     %__MODULE__{
       state
       | scheme:
           Map.put(
             state.scheme,
             scheme_name,
             body
           ),
         elixir:
           Map.update(
             state.elixir,
             module,
             %{name => body},
             &Map.put(&1, name, body)
           )
     }}
  end

  @impl true
  def handle_call({:get_elixir, module, name}, _from, state) do
    case Map.get(state.elixir, module) do
      nil ->
        # Lazily register
        register(module)

        if function_exported?(module, :__scheme_fns__, 0) do
          {_, _, name, _} =
            hd(
              Enum.filter(
                module.__scheme_fns__(),
                fn {_module, elixir_name, _scheme_name, _body} ->
                  name == elixir_name
                end
              )
            )

          {:reply, {:ok, name}, state}
        else
          {:reply, :absent, state}
        end

      mod_store ->
        case Map.get(mod_store, name) do
          nil -> {:reply, :absent, state}
          body -> {:reply, {:ok, body}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_scheme, name}, _from, state) do
    body = Map.get(state.scheme, name)
    {:reply, {:ok, body}, state}
  end

  @impl true
  def handle_call({:all_scheme}, _from, state) do
    {:reply, {:ok, state.scheme}, state}
  end
end
