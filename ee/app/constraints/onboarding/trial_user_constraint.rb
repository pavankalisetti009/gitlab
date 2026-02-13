# frozen_string_literal: true

module Onboarding
  class TrialUserConstraint
    include Gitlab::Experiment::Dsl

    def matches?(request)
      user = request.env['warden'].user

      return false unless user
      return false unless ::Onboarding::UserStatus.new(user).trial_registration?

      experiment(:lightweight_trial_registration_redesign, actor: user) do |e|
        e.control { false }
        e.candidate { true }
      end.run
    end
  end
end
