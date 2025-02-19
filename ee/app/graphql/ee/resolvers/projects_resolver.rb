# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :aimed_for_deletion, GraphQL::Types::Boolean,
          required: false,
          description: 'Return only projects marked for deletion.'
        argument :include_hidden, GraphQL::Types::Boolean,
          required: false,
          description: 'Include hidden projects.'
        argument :marked_for_deletion_on, ::Types::DateType,
          required: false,
          description: 'Date when the project was marked for deletion.'

        before_connection_authorization do |projects, current_user|
          ::Preloaders::UserMaxAccessLevelInProjectsPreloader.new(projects, current_user).execute

          if ::Feature.enabled?(:preload_member_roles, current_user)
            ::Preloaders::UserMemberRolesInProjectsPreloader.new(projects: projects, user: current_user).execute
          end
        end
      end

      private

      override :finder_params
      def finder_params(args)
        super(args)
          .merge(args.slice(:aimed_for_deletion, :include_hidden, :marked_for_deletion_on))
          .merge(
            filter_expired_saml_session_projects: ::Feature.enabled?(
              :filter_saml_enforced_resources_from_graphql, current_user
            )
          )
      end
    end
  end
end
