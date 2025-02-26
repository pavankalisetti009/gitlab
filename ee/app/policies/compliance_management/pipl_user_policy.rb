# frozen_string_literal: true

module ComplianceManagement
  class PiplUserPolicy < BasePolicy
    condition(:enforce_pipl_compliance) do
      Feature.enabled?(:enforce_pipl_compliance, @subject)
    end

    condition(:disable_delete_pipl_user) do
      Feature.disabled?(:delete_pipl_non_compliant_users, @subject)
    end

    rule { admin & enforce_pipl_compliance }.policy do
      enable :block_pipl_user
      enable :delete_pipl_user
    end

    rule { disable_delete_pipl_user }.policy do
      prevent :delete_pipl_user
    end
  end
end
