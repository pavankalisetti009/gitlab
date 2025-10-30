# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class Update < BaseMutation
          graphql_name 'AiCatalogItemConsumerUpdate'

          field :item_consumer,
            ::Types::Ai::Catalog::ItemConsumerType,
            null: true,
            description: 'Item consumer that was updated.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
            required: true,
            description: 'Global ID of the catalog item consumer to update.'

          argument :pinned_version_prefix, GraphQL::Types::String,
            required: false,
            description: 'Major version, minor version, or patch to pin the item to.'

          argument :service_account_id, ::Types::GlobalIDType[::User],
            required: false,
            description: 'Service account to associate with the item consumer.'

          argument :trigger_types, [GraphQL::Types::String],
            required: false,
            description: 'List of event types to create flow triggers for ' \
              '(values can be mention, assign or assign_reviewer).'

          authorize :admin_ai_catalog_item_consumer

          def resolve(args)
            item_consumer = authorized_find!(id: args[:id])

            params = args.slice(:pinned_version_prefix)

            result = ::Ai::Catalog::ItemConsumers::UpdateService.new(
              item_consumer,
              current_user,
              params
            ).execute

            item_consumer = result.payload[:item_consumer]
            item_consumer.reset unless result.success?

            {
              item_consumer: item_consumer,
              errors: result.errors
            }
          end
        end
      end
    end
  end
end
