# frozen_string_literal: true

module Ai
  class NamespaceSetting < ApplicationRecord
    self.table_name = "namespace_ai_settings"

    include HasRolePermissions

    enum :prompt_injection_protection_level, {
      log_only: 0,
      no_checks: 1,
      interrupt: 2
    }

    jsonb_accessor :feature_settings,
      duo_agent_platform_enabled: [:boolean, { default: true }]

    validates :feature_settings,
      json_schema: { filename: "ai_namespace_setting_feature_settings", size_limit: 64.kilobytes }

    validates :duo_workflow_mcp_enabled, inclusion: { in: [true, false] }
    validates :prompt_injection_protection_level, presence: true
    validates :ai_usage_data_collection_enabled, inclusion: { in: [true, false] }

    belongs_to :namespace, inverse_of: :ai_settings
  end
end
