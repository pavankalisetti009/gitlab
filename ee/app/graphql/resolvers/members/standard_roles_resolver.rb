# frozen_string_literal: true

module Resolvers
  module Members
    class StandardRolesResolver < BaseResolver
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Members::StandardRoleType, null: true

      def resolve(**_args)
        counts = Member.count_by_role

        result = Gitlab::Access.options_with_minimal_access.map do |name, access_level|
          row = counts.find { |c| c.access_level == access_level }
          count = row ? row.members_count : 0

          { name: name, access_level: access_level, members_count: count }
        end

        result.sort_by { |role| role[:access_level] }
      end

      def ready?(**args)
        if gitlab_com_subscription?
          # TODO: change this to check the group presence when on SaaS:
          # https://gitlab.com/gitlab-org/gitlab/-/work_items/477269
          raise_resource_not_available_error! 'The feature is not available for SaaS.'
        end

        super
      end
    end
  end
end
