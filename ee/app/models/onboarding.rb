# frozen_string_literal: true

module Onboarding
  REGISTRATION_TYPE = {
    free: 'free',
    trial: 'trial',
    invite: 'invite',
    subscription: 'subscription'
  }.freeze

  def self.enabled?
    ::Gitlab::Saas.feature_available?(:onboarding)
  end

  def self.user_onboarding_in_progress?(user)
    user.present? &&
      user.onboarding_in_progress? &&
      enabled?
  end
end
