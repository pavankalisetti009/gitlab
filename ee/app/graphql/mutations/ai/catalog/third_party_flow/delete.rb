# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ThirdPartyFlow
        class Delete < BaseMutation
          graphql_name 'AiCatalogThirdPartyFlowDelete'

          field :success, GraphQL::Types::Boolean,
            null: false,
            description: 'Returns true if catalog Third Party Flow was successfully deleted.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog Third Party Flow to delete.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            third_party_flow = authorized_find!(id: args[:id])

            result = ::Ai::Catalog::ThirdPartyFlows::DestroyService.new(
              project: third_party_flow.project,
              current_user: current_user,
              params: { item: third_party_flow }).execute

            {
              success: result.success?,
              errors: Array(result.errors)
            }
          end
        end
      end
    end
  end
end
