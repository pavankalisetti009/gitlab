# frozen_string_literal: true

module Ai
  module CustomizablePermission
    extend ActiveSupport::Concern

    def ai_minimum_access_level_to_execute
      resolve_ai_settings&.minimum_access_level_execute || ::Gitlab::Access::GUEST
    end

    def ai_minimum_access_level_to_execute_async
      resolve_ai_settings&.minimum_access_level_execute_async || ::Gitlab::Access::DEVELOPER
    end

    private

    def resolve_ai_settings
      gitlab_com? ? root_ancestor.ai_settings : Ai::Setting.instance
    end

    def gitlab_com?
      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end
  end
end
