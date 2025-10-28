# frozen_string_literal: true

module Resolvers
  module Security
    class AttributesResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type ::Types::Security::AttributeType.connection_type, null: true

      authorize :read_security_attribute

      description 'Resolves security attributes linked to a project.'

      def resolve
        project = object.is_a?(::Project) ? object : object.try(:project)
        return ::Security::Attribute.none unless project

        # Use authorized_resource? instead of authorize! to avoid raising an exception
        # This returns a boolean, allowing graceful handling when permission is denied
        return ::Security::Attribute.none unless authorized_resource?(project.namespace)

        return [] unless ::Feature.enabled?(:security_categories_and_attributes, project.root_ancestor)

        project.security_attributes.include_category
      end
    end
  end
end
