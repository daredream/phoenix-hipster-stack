defmodule App.PublicSchema do

  import List , only: [first: 1]
  alias GraphQL.Schema
  alias GraphQL.Type.ObjectType
  alias GraphQL.Type.List
  alias GraphQL.Type.NonNull
  alias GraphQL.Type.String
  alias GraphQL.Relay.Mutation
  alias RethinkDB.Query
  alias GraphQL.Relay.Connection
  @type_string %{type: %GraphQL.Type.String{}}
  alias GraphQL.Relay.Node

  @store %{
    id: 1
  }

  def node_interface do
    Node.define_interface(fn(obj)->
        case obj do
          @store ->
            App.Type.Store.type
          _ ->
            %{}
        end
    end)
  end



  def node_field do
    Node.define_field(node_interface, fn(_item, args, _ctx) ->
        [type, id] = Node.from_global_id(args[:id])
        case type do
          "Store" ->
            @store
          _ ->
            %{}
        end

    end )
  end



  def resolve_store(doc, _args, _) do
        @store
  end

  def schema do
    %Schema{
      query: %ObjectType{
        name: "Query",
        fields: %{
          node: node_field,
          store: %{
            type: App.Type.Store,
            resolve: {App.PublicSchema, :resolve_store}
          }
        }
      },
      mutation: %ObjectType{
        name: "Mutation",
        fields: %{
          createLink: Mutation.new(%{
            name: "CreateLink",
            input_fields: %{
              title: %{type: %NonNull{ofType: %String{}}},
              url: %{type: %NonNull{ofType: %String{}}}
            },
            output_fields: %{
              linkEdge: %{
                type: App.Type.LinkConnection.get[:edge_type],
                resolve: fn(input, args, info) -> output_fields_resolve(input, args, info) end
              },
              store: %{
                type: App.Type.Store,
                resolve: fn(input, args, info) -> resolve_store(input, args, info) end
              }
            },
            mutate_and_get_payload: fn(input, info) ->
                mutate_and_get_payload(input, info)
            end
          })
        }
      }
    }
  end

  def output_fields_resolve(obj, _args, _info) do
      %{
        node: App.Query.Link.get_from_id(first(obj[:generated_keys])),
        cursor: first(obj[:generated_keys])
      }
  end


  def mutate_and_get_payload(input, _info) do
    Query.table("links")
      |> Query.insert(
        %{
          title: input["title"],
          url: input["url"],
          timestamp: TimeHelper.currentTime
          })
      |> DB.run
      |> DB.handle_graphql_resp
  end

end
