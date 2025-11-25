defmodule Anoma.LocalDomain.SchemeRegistry do
  use GenServer
  use TypedStruct

  typedstruct do
    field(:scheme, any(), default: Map.new())
    field(:ast, any(), default: Map.new())
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start with a standard environment

    std =
      %__MODULE__{
        ast: %{},
        scheme: %{
          +: {:native, :erlang, :+},
          -: {:native, :erlang, :-},
          ==: {:native, :erlang, :==},
          is_number: {:native, :erlang, :is_number},
          get: {:native, Map, :get},
          put: {:native, Map, :put},
          not: {:native, :erlang, :not},
          length:
            {:closure, [:xs],
             [
               :if,
               [:==, :xs, nil],
               0,
               [:+, 1, [:length, [:cdr, :xs]]]
             ]},
          is_integer: {:native, :erlang, :is_integer},
          at:
            {:closure, [:xs, :n],
             [
               :if,
               [:==, :n, 0],
               [:car, :xs],
               [:at, [:cdr, :xs], [:-, :n, 1]]
             ]},
          map:
            {:closure, [:xs, :f],
             [
               :if,
               [:==, :xs, nil],
               nil,
               [
                 :cons,
                 [:f, [:car, :xs]],
                 [:map, [:cdr, :xs], :f]
               ]
             ]},
          filter:
            {:closure, [:xs, :f],
             [
               :if,
               [:==, :xs, nil],
               nil,
               [
                 :if,
                 [:f, [:car, :xs]],
                 [
                   :cons,
                   [:car, :xs],
                   [:filter, [:cdr, :xs], :f]
                 ],
                 [:filter, [:cdr, :xs], :f]
               ]
             ]},
          nthcdr:
            {:closure, [:xs, :n],
             [
               :if,
               [:==, :n, 0],
               :xs,
               [:nthcdr, [:cdr, :xs], [:-, :n, 1]]
             ]},
          take:
            {:closure, [:xs, :n],
             [
               :if,
               [:==, :n, 0],
               nil,
               [
                 :cons,
                 [:car, :xs],
                 [:take, [:cdr, :xs], [:-, :n, 1]]
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
    for {name, args_scheme, ast} <- module.__elixir_fns__() do
      put_ast(
        module,
        name,
        %{args: args_scheme, ast: ast}
      )

      put_scheme(
        name,
        args_scheme,
        {module, name}
      )
    end

    for {name_scheme, args_scheme, body_scheme} <-
          module.__scheme_fns__() do
      put_scheme(
        name_scheme,
        args_scheme,
        body_scheme
      )
    end
  end

  def put_ast(module, name, %{args: args, ast: ast}) do
    GenServer.cast(__MODULE__, {:put_ast, module, name, args, ast})
  end

  def put_scheme(name_scheme, args_scheme, body_scheme) do
    GenServer.cast(
      __MODULE__,
      {:put_scheme, name_scheme, args_scheme, body_scheme}
    )
  end

  def get_scheme(name_scheme) do
    case GenServer.call(__MODULE__, {:get_scheme, name_scheme}) do
      {:ok, {module, name}} ->
        {:ok, args, ast} =
          Anoma.LocalDomain.SchemeRegistry.get_ast(module, name)

        Anoma.LocalDomain.Scheme.ast_to_scheme(args, ast)

      {:ok, body} ->
        body
    end
  end

  def get_ast(module, name) do
    GenServer.call(__MODULE__, {:get_ast, module, name})
  end

  def all_scheme() do
    {:ok, scheme_fns} = GenServer.call(__MODULE__, {:all_scheme})

    {:ok,
     Enum.map(
       Map.keys(scheme_fns),
       fn name_scheme ->
         {name_scheme, get_scheme(name_scheme)}
       end
     )
     |> Map.new()}
  end

  @impl true
  def handle_cast({:put_ast, module, name, args, ast}, state) do
    {:noreply,
     %__MODULE__{
       state
       | ast:
           Map.update(
             state.ast,
             module,
             %{name => %{args: args, ast: ast}},
             &Map.put(&1, name, %{args: args, ast: ast})
           )
     }}
  end

  @impl true
  def handle_cast(
        {:put_scheme, name_scheme, args_scheme, body_scheme},
        state
      ) do
    {:noreply,
     %__MODULE__{
       state
       | scheme:
           Map.put(
             state.scheme,
             name_scheme,
             case body_scheme do
               {module, name} -> {module, name}
               body_scheme -> {:closure, args_scheme, body_scheme}
             end
           )
     }}
  end

  @impl true
  def handle_call({:get_scheme, name_scheme}, _from, state) do
    body = Map.get(state.scheme, name_scheme)
    {:reply, {:ok, body}, state}
  end

  @impl true
  def handle_call({:get_ast, module, name}, _from, state) do
    case Map.get(state.ast, module) do
      nil ->
        # Lazily register
        register(module)

        if function_exported?(module, :__elixir_fns__, 0) do
          {_name, args_scheme, ast} =
            hd(
              Enum.filter(
                module.__elixir_fns__(),
                fn {name_elixir, _args_scheme, _ast} ->
                  name == name_elixir
                end
              )
            )

          {:reply, {:ok, args_scheme, ast}, state}
        else
          {:reply, :absent, state}
        end

      mod_store ->
        case Map.get(mod_store, name) do
          nil ->
            {:reply, :absent, state}

          %{args: args_scheme, ast: ast} ->
            {:reply, {:ok, args_scheme, ast}, state}
        end
    end
  end

  @impl true
  def handle_call({:all_scheme}, _from, state) do
    {:reply, {:ok, state.scheme}, state}
  end
end
