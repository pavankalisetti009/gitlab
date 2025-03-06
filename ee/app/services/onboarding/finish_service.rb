# frozen_string_literal: true

module Onboarding
  class FinishService
    include Gitlab::Utils::StrongMemoize

    def initialize(user)
      @user = user
    end

    def execute
      return unless valid_to_finish?

      user.update(onboarding_attributes)
    end

    def onboarding_attributes
      return {} unless Onboarding.user_onboarding_in_progress?(user)

      { onboarding_in_progress: false }
    end
    strong_memoize_attr :onboarding_attributes

    private

    attr_reader :user

    def valid_to_finish?
      onboarding_attributes.present?
    end
  end
end
