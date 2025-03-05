# frozen_string_literal: true

module Types
  module WorkItems
    module WidgetDefinitions
      # rubocop:disable Graphql/AuthorizeTypes -- Authorization too granular, parent type is authorized
      class CustomFieldsType < BaseObject
        graphql_name 'WorkItemWidgetDefinitionCustomFields'
        description 'Represents a custom fields widget definition'

        implements ::Types::WorkItems::WidgetDefinitionInterface

        field :custom_fields, [::Types::Issuables::CustomFieldType],
          null: true,
          description: 'Custom fields available for the work item type. ' \
            'Available only when feature flag `custom_fields_feature` is enabled.',
          resolver: ::Resolvers::WorkItems::TypeCustomFieldsResolver,
          experiment: { milestone: '17.10' }
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
