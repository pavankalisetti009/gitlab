# frozen_string_literal: true

module Ai
  class NamespaceSettingNullObjectPolicy < BasePolicy
    # Null object policy - delegates to nil namespace
    # This allows authorization checks to pass when ai_settings doesn't exist
    delegate { nil }
  end
end
