# frozen_string_literal: true

module Members
  module ServiceAccounts
    # Base class for filtering relations based on composite identity service account rules.
    #
    # A user is ALLOWED if ANY of these is true:
    # - Not a service account
    # - Not composite_identity_enforced
    # - Instance-wide SA (provisioned_by_group_id IS NULL)
    # - Provisioned by the target group or its ancestors
    #
    # This class provides the core SQL logic and conditions. Subclasses implement
    # the specific relation handling (Users vs Members).
    class CompositeIdFinder
      def initialize(group)
        @group = group
      end

      def execute
        raise NotImplementedError, 'Subclasses must implement #execute'
      end

      private

      attr_reader :group

      def allowed_conditions
        [
          allowed_sql,
          {
            service_account_type: ::User.user_types[:service_account],
            allowed_group_ids: group.self_and_ancestor_ids
          }
        ]
      end

      def allowed_sql
        <<~SQL.squish
          users.user_type != :service_account_type
          OR users.composite_identity_enforced = FALSE
          OR user_details.provisioned_by_group_id IS NULL
          OR user_details.provisioned_by_group_id IN (:allowed_group_ids)
        SQL
      end
    end
  end
end
