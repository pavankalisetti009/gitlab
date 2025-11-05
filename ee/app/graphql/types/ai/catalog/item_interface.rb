# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      module ItemInterface
        include Types::BaseInterface
        prepend Gitlab::Graphql::ExposePermissions

        RESOLVE_TYPES = {
          ::Ai::Catalog::Item::AGENT_TYPE => ::Types::Ai::Catalog::AgentType,
          ::Ai::Catalog::Item::FLOW_TYPE => ::Types::Ai::Catalog::FlowType,
          ::Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE => ::Types::Ai::Catalog::ThirdPartyFlowType
        }.freeze

        graphql_name 'AiCatalogItem'
        description 'An AI catalog item'

        connection_type_class ::Types::CountableConnectionType

        expose_permissions ::Types::PermissionTypes::Ai::Catalog::Item

        field :created_at, ::Types::TimeType, null: false, description: 'Timestamp of when the item was created.'
        field :updated_at, ::Types::TimeType, null: false, description: 'Timestamp of when the item was updated.'
        field :soft_deleted_at, ::Types::TimeType, method: :deleted_at, null: true,
          description: 'Timestamp of when the item was soft deleted.'
        field :soft_deleted, GraphQL::Types::Boolean, method: :deleted?, null: true,
          description: 'Indicates if the item has been soft deleted.'
        field :description, GraphQL::Types::String, null: false, description: 'Description of the item.'
        field :id, GraphQL::Types::ID, null: false, description: 'ID of the item.'
        field :item_type,
          ItemTypeEnum,
          null: false,
          description: 'Type of the item.'
        field :name, GraphQL::Types::String, null: false, description: 'Name of the item.'
        field :project, ::Types::ProjectType, null: true, description: 'Project for the item.'
        field :public, GraphQL::Types::Boolean,
          null: false,
          description: 'Whether the item is publicly visible in the catalog.'
        field :versions, ::Types::Ai::Catalog::VersionInterface.connection_type,
          null: true,
          description: 'Versions of the item.'
        field :latest_version, ::Types::Ai::Catalog::VersionInterface,
          null: true,
          description: 'Latest version of the item.' do
            argument :released, ::GraphQL::Types::Boolean, required: false,
              description: 'Return the latest released version.'
          end
        field :configuration_for_project, ::Types::Ai::Catalog::ItemConsumerType,
          null: true,
          experiment: { milestone: '18.6' },
          description: 'Item configuration for the given project.' do
          argument :project_id, ::Types::GlobalIDType[::Project], required: true,
            description: 'Global ID of the project to return the item configuration of.'
        end

        orphan_types ::Types::Ai::Catalog::AgentType
        orphan_types ::Types::Ai::Catalog::FlowType
        orphan_types ::Types::Ai::Catalog::ThirdPartyFlowType

        def latest_version(released: nil)
          version_id = released ? object.latest_released_version_id : object.latest_version_id
          return unless version_id

          lazy_version = Gitlab::Graphql::Loaders::BatchModelLoader.new(
            ::Ai::Catalog::ItemVersion,
            version_id
          ).find

          # `ItemVersion#item` is needed for `VersionInterface.resolve_type` and authorization checks.
          # After batch loading, set the association in place to avoid further loading of `Item` records.
          Gitlab::Graphql::Lazy.with_value(lazy_version) do |version|
            version.tap { |v| v.item = object }
          end
        end

        def configuration_for_project(project_id:)
          BatchLoader::GraphQL.for(project_id.model_id.to_i).batch do |project_ids, loader|
            ::Ai::Catalog::ItemConsumer.for_item(object).for_projects(project_ids).each do |consumer|
              loader.call(consumer.project_id, consumer)
            end
          end
        end

        def self.resolve_type(item, _context)
          RESOLVE_TYPES[item.item_type.to_sym] or raise "Unknown catalog item type: #{item.item_type}" # rubocop:disable Style/AndOr -- Syntax error when || is used
        end
      end
    end
  end
end
