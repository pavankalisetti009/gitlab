# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class ItemConsumerType < ::Types::BaseObject
        graphql_name 'AiCatalogItemConsumer'
        description 'An AI catalog item configuration'
        authorize :read_ai_catalog_item_consumer

        connection_type_class ::Types::CountableConnectionType

        field :enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates if the configuration item is enabled.'
        field :flow_trigger, ::Types::Ai::FlowTriggerType,
          null: true,
          description: 'Trigger associated with the configured catalog item.'
        field :group, ::Types::GroupType,
          null: true,
          description: 'Group in which the catalog item is configured.'
        field :id, GraphQL::Types::ID,
          null: false,
          description: 'ID of the configuration item.'
        field :item, ::Types::Ai::Catalog::ItemInterface,
          null: true,
          description: 'Configuration catalog item.'
        field :organization, ::Types::Organizations::OrganizationType,
          null: true,
          description: 'Organization in which the catalog item is configured.'
        field :parent_item_consumer, ::Types::Ai::Catalog::ItemConsumerType,
          null: true,
          description: 'Parent item consumer associated with the configured catalog item.'
        field :pinned_version_prefix, GraphQL::Types::String,
          null: true,
          description: 'Major version, minor version, or patch item is pinned to.'
        field :project, ::Types::ProjectType,
          null: true,
          description: 'Project in which the catalog item is configured.'
        field :service_account, ::Types::UserType,
          null: true,
          description: 'Service account associated with the item consumer.'

        def item
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::Item, object.ai_catalog_item_id).find
        end

        def parent_item_consumer
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::ItemConsumer, object.parent_item_consumer_id)
            .find
        end

        def service_account
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(User, object.service_account_id).find
        end

        def flow_trigger
          BatchLoader::GraphQL.for(object.id).batch do |item_consumer_ids, loader|
            ::Ai::FlowTrigger.by_item_consumer_ids(item_consumer_ids).each do |trigger|
              loader.call(trigger.ai_catalog_item_consumer_id, trigger)
            end
          end
        end
      end
    end
  end
end
