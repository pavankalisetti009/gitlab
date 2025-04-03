# frozen_string_literal: true

module Resolvers
  module Issuables
    class CustomFieldResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      authorize :read_custom_field

      type Types::Issuables::CustomFieldType, null: true

      argument :id, ::Types::GlobalIDType[::Issuables::CustomField],
        required: true,
        description: 'Global ID of the custom field.'

      def resolve(id:)
        custom_field = authorized_find!(id: id)

        return unless Feature.enabled?(:custom_fields_feature, custom_field.namespace)

        custom_field
      end
    end
  end
end
