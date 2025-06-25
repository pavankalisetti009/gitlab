# frozen_string_literal: true

module Import
  module UserMapping
    class EnterpriseBypassAuthorizer
      def initialize(group, assignee_user, reassigned_by_user)
        @group = group.root_ancestor
        @assignee_user = assignee_user
        @reassigned_by_user = reassigned_by_user
      end

      def allowed?
        ::Feature.enabled?(:group_owner_placeholder_confirmation_bypass, group) &&
          reassigned_by_user.can?(:admin_namespace, group) &&
          group.namespace_settings.allow_enterprise_bypass_placeholder_confirmation? &&
          assignee_user.managed_by_group?(group)
      end

      private

      attr_reader :group, :assignee_user, :reassigned_by_user
    end
  end
end
