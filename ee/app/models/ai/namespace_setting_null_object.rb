# frozen_string_literal: true

module Ai
  class NamespaceSettingNullObject
    # Null object pattern for Ai::NamespaceSetting
    # Returns default values when the record doesn't exist

    def duo_agent_platform_enabled
      true
    end

    def foundational_agents_default_enabled
      true
    end
  end
end
