# frozen_string_literal: true

module Ai
  class NamespaceSetting < ApplicationRecord
    self.table_name = "namespace_ai_settings"

    include HasRolePermissions

    jsonb_accessor :feature_settings,
      duo_agent_platform_enabled: [:boolean, { default: true }]

    validates :feature_settings,
      json_schema: { filename: "ai_namespace_setting_feature_settings", size_limit: 64.kilobytes }

    validates :duo_workflow_mcp_enabled, inclusion: { in: [true, false] }

    belongs_to :namespace, inverse_of: :ai_settings
  end
end
