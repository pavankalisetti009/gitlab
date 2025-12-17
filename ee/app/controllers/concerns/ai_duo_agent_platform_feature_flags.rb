# frozen_string_literal: true

module AiDuoAgentPlatformFeatureFlags
  extend ActiveSupport::Concern

  included do
    before_action :set_ai_duo_agent_platform_ga_rollout
  end

  private

  def set_ai_duo_agent_platform_ga_rollout
    gon.ai_duo_agent_platform_ga_rollout = ga_rolled_out
  end

  def ga_rolled_out
    if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      ::Feature.enabled?(:ai_duo_agent_platform_ga_rollout, :instance)
    else
      ::Feature.enabled?(:ai_duo_agent_platform_ga_rollout_self_managed, :instance)
    end
  end
end
