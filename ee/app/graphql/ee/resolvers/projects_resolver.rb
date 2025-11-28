# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :include_hidden, GraphQL::Types::Boolean,
          required: false,
          description: 'Include hidden projects.'

        argument :with_duo_eligible, GraphQL::Types::Boolean,
          required: false,
          experiment: { milestone: '18.6' },
          description: "Include only projects that are eligible for GitLab Duo and have Duo features enabled." \
            "Applies only if the feature flag `with_duo_eligible_projects_filter` is enabled."

        before_connection_authorization do |projects, current_user|
          ::Preloaders::UserMaxAccessLevelInProjectsPreloader.new(projects, current_user).execute
          ::Preloaders::UserMemberRolesInProjectsPreloader.new(projects: projects, user: current_user).execute
        end
      end

      private

      override :finder_params
      def finder_params(args)
        super(args)
          .merge(
            args.slice(
              :include_hidden,
              :with_duo_eligible
            )
          )
          .merge(filter_expired_saml_session_projects: true)
      end
    end
  end
end
