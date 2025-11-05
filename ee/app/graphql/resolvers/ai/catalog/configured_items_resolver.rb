# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ConfiguredItemsResolver < BaseResolver
        description 'Find AI Catalog items configured for use.'

        type ::Types::Ai::Catalog::ItemConsumerType.connection_type, null: false

        argument :group_id,
          ::Types::GlobalIDType[::Group],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Group ID to retrieve configured AI Catalog items for.'

        argument :include_inherited,
          GraphQL::Types::Boolean,
          required: false,
          default_value: true,
          description: 'Include configured AI Catalog items inherited from parent groups.'

        argument :item_id,
          ::Types::GlobalIDType[::Ai::Catalog::Item],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Item ID to retrieve configured AI Catalog items for.'

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Project ID to retrieve configured AI Catalog items for.'

        argument :item_type, ::Types::Ai::Catalog::ItemTypeEnum,
          required: false,
          description: 'Type of items to retrieve.'

        argument :item_types, [::Types::Ai::Catalog::ItemTypeEnum],
          required: false,
          description: 'Types of items to retrieve.'

        validates at_least_one_of: [:group_id, :project_id]

        def resolve(**args)
          return none unless ::Feature.enabled?(:global_ai_catalog, current_user)

          ::Ai::Catalog::ItemConsumersFinder.new(current_user, params: args).execute
        end

        private

        def none
          ::Ai::Catalog::ItemConsumer.none
        end
      end
    end
  end
end
