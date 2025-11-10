defmodule Anoma.LocalDomain.Action do
  @moduledoc """
  I define the struct for ARM actions
  """

  use TypedStruct

  typedstruct enforce: true do
    # field(:label, any())
    field(:consumed, any())
    field(:created, any())
  end

  def transact_expression(expression, result) do
    [method | consumed] = expression

    %__MODULE__{
      created: [
        Anoma.LocalDomain.ObjToResource.obj_to_resource(method),
        Anoma.LocalDomain.ObjToResource.obj_to_resource(result)
      ],
      consumed:
        Enum.map(consumed, fn obj ->
          Anoma.LocalDomain.ObjToResource.obj_to_resource(obj)
        end)
    }
  end

  defmacro transact(expression) do
    {{:., _, [mod_ast, name]}, _, args} = expression
    arity = length(args)
    mod = Macro.expand(mod_ast, __CALLER__)

    quote do
      Anoma.LocalDomain.Action.transact_expression(
        [
          (&(unquote(mod).unquote(name) / unquote(arity)))
          | unquote(args)
        ],
        unquote(expression)
      )
    end
  end

  def to_scheme(%Anoma.LocalDomain.Action{
        consumed: consumed,
        created: created
      }) do
    %{
      consumed: [
        "list"
        | Enum.map(consumed, fn c ->
            Anoma.LocalDomain.ObjToResource.scheme(c.data)
          end)
      ],
      created: [
        "list"
        | Enum.map(created, fn c ->
            Anoma.LocalDomain.ObjToResource.scheme(c.data)
          end)
      ]
    }
  end
end
