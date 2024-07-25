# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterprise
    ELIGIBLE_PLANS = [::Plan::ULTIMATE, ::Plan::ULTIMATE_TRIAL].freeze
  end
end
