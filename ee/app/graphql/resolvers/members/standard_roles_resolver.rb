# frozen_string_literal: true

module Resolvers
  module Members
    class StandardRolesResolver < BaseResolver
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Members::StandardRoleType, null: true

      def resolve(**_args)
        result = Gitlab::Access.options_with_minimal_access.map do |name, access_level|
          row = counts.find { |c| c.access_level == access_level }
          count = row ? row.members_count : 0

          { name: name, access_level: access_level, members_count: count, group: object }
        end

        result.sort_by { |role| role[:access_level] }
      end

      def ready?(**args)
        return true if object

        raise_resource_not_available_error!('You have to specify group for SaaS.') if gitlab_com_subscription?

        super
      end

      def counts
        if object
          Member.for_self_and_descendants(object).count_by_role
        else
          Member.count_by_role
        end
      end
      strong_memoize_attr :counts
    end
  end
end
