# frozen_string_literal: true

module Resolvers
  module Security
    class ProjectSecurityExclusionResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::ProjectSecurityExclusionType.connection_type, null: true

      authorize :read_project_security_exclusions

      description 'Find security scanner exclusions for a project.'

      argument :scanner, Types::Security::ExclusionScannerEnum, required: false,
        description: 'Filter entries by scanner.'

      argument :type, Types::Security::ExclusionTypeEnum, required: false,
        description: 'Filter entries by exclusion type.'

      argument :active, GraphQL::Types::Boolean, required: false,
        description: 'Filter entries by active status.'

      def resolve(**args)
        raise_resource_not_available_error! unless object.licensed_feature_available?(:security_exclusions)

        ::Security::ProjectSecurityExclusionsFinder.new(current_user, project: object, params: args).execute
      end
    end
  end
end
