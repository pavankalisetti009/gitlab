# frozen_string_literal: true

module Resolvers
  module Members
    class StandardRolesResolver < BaseResolver
      include LooksAhead
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Members::StandardRoleType, null: true

      def resolve_with_lookahead
        result = Gitlab::Access.options_with_minimal_access.map do |name, access_level|
          members_row = member_counts.find { |c| c.access_level == access_level } if selects_field?(:members_count)
          users_row = user_counts.find { |c| c.access_level == access_level } if selects_field?(:users_count)

          {
            name: name,
            access_level: access_level,
            members_count: members_row&.members_count || 0,
            users_count: users_row&.users_count || 0,
            group: object
          }
        end

        result.sort_by { |role| role[:access_level] }
      end

      def ready?(**args)
        return true if object

        raise_resource_not_available_error!('You have to specify group for SaaS.') if gitlab_com_subscription?

        super
      end

      private

      def member_counts
        member = object ? Member.for_self_and_descendants(object) : Member

        member.with_static_role.count_members_by_role
      end
      strong_memoize_attr :member_counts

      def user_counts
        member = object ? Member.for_self_and_descendants(object) : Member

        member.with_static_role.count_users_by_role
      end
      strong_memoize_attr :user_counts

      def selected_fields
        node_selection.selections.map(&:name)
      end

      def selects_field?(name)
        lookahead.selects?(name) || selected_fields.include?(name)
      end
    end
  end
end
