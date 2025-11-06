# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class Create < BaseMutation
          graphql_name 'AiCatalogItemConsumerCreate'

          field :item_consumer,
            ::Types::Ai::Catalog::ItemConsumerType,
            null: true,
            description: 'Item configuration created.'

          argument :item_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            loads: ::Types::Ai::Catalog::ItemInterface,
            description: 'Item to configure.'

          argument :pinned_version_prefix, GraphQL::Types::String,
            required: false,
            description: 'Major version, minor version, or patch to pin the item to.'

          argument :target, Types::Ai::Catalog::ItemConsumerTargetInputType,
            required: true,
            description: 'Target in which the catalog item is configured.'

          argument :trigger_types, [GraphQL::Types::String],
            required: false,
            description: 'List of event types to create flow triggers for ' \
              '(values can be mention, assign or assign_reviewer).'

          argument :parent_item_consumer_id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
            required: false,
            description: 'Parent item consumer belonging to the top-level group.'

          authorize :admin_ai_catalog_item_consumer

          def resolve(item:, target:, **args)
            group_id = target[:group_id]
            group = group_id ? authorized_find!(id: group_id) : nil
            project_id = target[:project_id]
            project = project_id ? authorized_find!(id: project_id) : nil
            parent_item_consumer_id = args[:parent_item_consumer_id]
            parent_item_consumer = parent_item_consumer_id ? authorized_find!(id: parent_item_consumer_id) : nil

            raise_resource_not_available_error! unless allowed?(item)

            result = ::Ai::Catalog::ItemConsumers::CreateService.new(
              container: group || project,
              current_user: current_user,
              params: service_args(item, parent_item_consumer, args)
            ).execute

            { item_consumer: result.payload&.dig(:item_consumer), errors: result.errors }
          end

          private

          def allowed?(item)
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
          end

          def service_args(item, parent_item_consumer, args)
            args[:item] = item
            args[:parent_item_consumer] = parent_item_consumer
            args
          end
        end
      end
    end
  end
end
