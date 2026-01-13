# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class MembershipEligibilityChecker
      def initialize(target_namespace)
        @target_namespace = target_namespace
      end

      # rubocop:disable CodeReuse/ActiveRecord -- required for implementation of the service in multiple spots
      # Filters a User relation to only include users eligible for membership within target_namespace.
      def filter_users(users_relation)
        return users_relation unless target_namespace # no-op as a safe default
        return users_relation unless any_restrictions_enabled?

        users_relation
          .left_joins(:user_detail)
          .joins(
            "LEFT JOIN namespaces AS provision_groups ON user_details.provisioned_by_group_id = provision_groups.id"
          )
          .where(*build_eligibility_conditions)
      end

      def eligible?(user)
        return true unless target_namespace
        return true unless user&.service_account?

        !restricted?(user)
      end

      private

      attr_reader :target_namespace

      def restricted?(user)
        return false unless target_namespace
        return false unless user&.service_account?

        restricted_by_composite_identity?(user) || restricted_by_subgroup_hierarchy?(user)
      end

      def build_eligibility_conditions
        conditions = []

        conditions << composite_identity_condition if composite_identity_restrictions_enabled?
        conditions << subgroup_hierarchy_condition if subgroup_restrictions_enabled?

        full_condition = "users.user_type != :sa_type OR (#{conditions.join(' AND ')})"

        [full_condition, query_params]
      end

      def composite_identity_condition
        <<~SQL.squish
          (
            users.composite_identity_enforced = FALSE
            OR user_details.provisioned_by_group_id IS NULL
            OR user_details.provisioned_by_group_id IN (:allowed_group_ids)
          )
        SQL
      end

      def subgroup_hierarchy_condition
        <<~SQL.squish
          (
            user_details.provisioned_by_group_id IS NULL
            OR user_details.provisioned_by_group_id IN (:allowed_group_ids)
            OR provision_groups.parent_id IS NULL
          )
        SQL
      end

      def query_params
        {
          sa_type: ::User.user_types[:service_account],
          allowed_group_ids: target_namespace.self_and_ancestor_ids
        }
      end

      def composite_identity_restrictions_enabled?
        ::Gitlab::Saas.feature_available?(:service_accounts_invite_restrictions)
      end

      def subgroup_restrictions_enabled?
        ::Feature.enabled?(:allow_subgroups_to_create_service_accounts, target_namespace.root_ancestor)
      end

      def any_restrictions_enabled?
        composite_identity_restrictions_enabled? || subgroup_restrictions_enabled?
      end

      def restricted_by_composite_identity?(user)
        return false unless composite_identity_restrictions_enabled?
        return false unless user.composite_identity_enforced?
        return false if user.provisioned_by_group_id.nil?

        !in_allowed_hierarchy?(user)
      end

      def restricted_by_subgroup_hierarchy?(user)
        return false unless subgroup_restrictions_enabled?

        provisioned_group = user.provisioned_by_group
        return false unless provisioned_group&.has_parent?

        !in_allowed_hierarchy?(user)
      end

      def in_allowed_hierarchy?(user)
        target_namespace.self_and_ancestor_ids.include?(user.provisioned_by_group_id)
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
