# frozen_string_literal: true

module Resolvers
  module Vulnerabilities
    class IdentifierSearchResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      authorize :read_security_resource

      type [GraphQL::Types::String], null: false

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Search identifier by name. Substring or partial match search is supported and ' \
          'argument should be greater than 3 characters.'

      def resolve(**args)
        authorize!

        return unless args[:name].present?

        validate_args(args)

        ::Vulnerabilities::Identifier.search_identifier_name(
          object.project_id, args[:name])
      end

      private

      def validate_args(args)
        if Feature.disabled?(:vulnerability_filtering_by_identifier, object, type: :beta)
          raise ::Gitlab::Graphql::Errors::ArgumentError,
            'Feature flag `vulnerability_filtering_by_identifier` is disabled for the project.'
        end

        return unless args[:name].length < 3

        raise ::Gitlab::Graphql::Errors::ArgumentError,
          'Name should be greater than 3 characters.'
      end

      def authorize!
        Ability.allowed?(context[:current_user], :read_security_resource, object) ||
          raise_resource_not_available_error!
      end
    end
  end
end
