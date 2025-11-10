# defmodule Anoma.LocalDomain.FixedSupply do
#   use TypedStruct

#   typedstruct enforced: true do
#     field(:quantity, integer())
#     field(:should_create, boolean())
#   end

# end

# defimpl Anoma.LocalDomain.ObjToResource, for: Anoma.LocalDomain.FixedSupply do
#   def obj_to_resource(x) do
#     %Anoma.LocalDomain.Resource{
#       data: x,
#       logic: fn obj, instance, consumedp ->
#         if consumedp do
#           true
#         else
#           Enum.filter(
#           if obj.should_create do
#             instance.created
#           else
#             instance.consumed
#           end,
#             fn finding ->
#               finding.__struct__ == obj.__struct__ && finding.quantity == obj.quantity
#             end
#           )
#         end
#       end
#     }
#   end

#   def scheme(x) do
#     %{
#       data: %{type: :fixed_supply, quantity: x.quantity, should_create: x.should_create},
#       logic: [
#         "lambda",
#         ["obj", "instance", "consumedp"],
#         [
#           "if", "consumedp", "true",
#           ["filter",
#            ["lambda" ["x"],
#             ["==",
#              ["get", ["get", "x", :data], :type],
#              ["get", ["get", "obj", :data], :type]
#             ]
#            ],
#            ["if",
#             ["get", ["get", "obj", :data], :should_create],
#             ["get", "instance", :created],
#             ["get", "instance", :consumed]
#           ]
#         ]
#         ]
#       ],
#       quantity: x.quantity
#     }
#   end
# end
