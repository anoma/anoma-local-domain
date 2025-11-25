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

  def empty?(%__MODULE__{consumed: consumed, created: created}) do
    consumed == [] && created == []
  end

  def related_objects_for_resources(resources, created?) do
    Enum.reduce(
      resources,
      %__MODULE__{consumed: [], created: []},
      fn resource, acc ->
        related =
          case created? do
            true ->
              Anoma.LocalDomain.ObjToResource.related_create(
                resource.data
              )

            false ->
              Anoma.LocalDomain.ObjToResource.related_use(resource.data)
          end

        %__MODULE__{
          consumed:
            acc.consumed ++
              Enum.map(
                related[:consumed],
                &Anoma.LocalDomain.ObjToResource.obj_to_resource/1
              ),
          created:
            acc.created ++
              Enum.map(
                related[:created],
                &Anoma.LocalDomain.ObjToResource.obj_to_resource/1
              )
        }
      end
    )
  end

  def compute_related(%__MODULE__{consumed: consumed, created: created}) do
    related_use = related_objects_for_resources(consumed, false)
    related_create = related_objects_for_resources(created, true)

    related_objects = %__MODULE__{
      consumed: related_use.consumed ++ related_create.consumed,
      created: related_use.created ++ related_create.created
    }

    if empty?(related_objects) do
      %__MODULE__{
        consumed: consumed,
        created: created
      }
    else
      recur = compute_related(related_objects)

      %__MODULE__{
        consumed: consumed ++ recur.consumed,
        created: created ++ recur.created
      }
    end
  end

  def transact_expression(expression, result) do
    [method | consumed] = expression

    action = %__MODULE__{
      created: [
        Anoma.LocalDomain.ObjToResource.obj_to_resource(method),
        Anoma.LocalDomain.ObjToResource.obj_to_resource(result)
      ],
      consumed:
        Enum.map(consumed, fn obj ->
          Anoma.LocalDomain.ObjToResource.obj_to_resource(obj)
        end)
    }

    # TODO Calculate related resources for each resource, add to action
    compute_related(action)
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
      "consumed" => [
        :list
        | Enum.map(consumed, fn c ->
            Anoma.LocalDomain.ObjToResource.scheme(c)
          end)
      ],
      "created" => [
        :list
        | Enum.map(created, fn c ->
            Anoma.LocalDomain.ObjToResource.scheme(c)
          end)
      ]
    }
  end
end
