# frozen_string_literal: true

module Security
  class PolicySetting < ApplicationRecord
    self.table_name = 'security_policy_settings'

    include SingletonRecord

    validates :csp_namespace, top_level_group: true

    validate :validate_csp_is_group

    # A group for managing Centralized Security Policies
    belongs_to :csp_namespace, class_name: 'Group', optional: true

    def self.csp_enabled?(group)
      return false if GitlabSubscriptions::SubscriptionHelper.gitlab_com_subscription?

      instance.csp_namespace_id.present? && (
        ::Feature.enabled?(:security_policies_csp, group) ||
          ::Feature.enabled?(:security_policies_csp, group&.root_ancestor)
      )
    end

    private

    def validate_csp_is_group
      return if csp_namespace_id.blank?
      return if csp_namespace&.group_namespace?

      errors.add(:csp_namespace, 'must be a group')
    end
  end
end
