# frozen_string_literal: true

module GitlabSubscriptions
  class TrialDurationService
    CACHE_EXPIRY = 1.hour
    CACHE_KEY = 'gitlab_subscriptions_trial_duration_service'

    DEFAULT_DURATIONS = {
      GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: 30 },
      GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE => { duration_days: 60 }
    }.freeze

    attr_reader :trial_type

    def initialize(trial_type = GitlabSubscriptions::Trials::FREE_TRIAL_TYPE)
      @trial_type = trial_type
    end

    def execute
      duration = find_trial_types[trial_type] || default_duration

      return duration[:duration_days] unless duration[:next_active_time]
      return duration[:duration_days] if Time.zone.parse(duration[:next_active_time]).future?

      duration[:next_duration_days]
    rescue ArgumentError, TypeError
      duration[:duration_days]
    end

    private

    def find_trial_types
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRY, race_condition_ttl: 30.seconds) do
        trial_types_request
      end || {}
    end

    def default_duration
      DEFAULT_DURATIONS[trial_type] || DEFAULT_DURATIONS[GitlabSubscriptions::Trials::FREE_TRIAL_TYPE]
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def trial_types_request
      response = client.namespace_trial_types

      if response[:success]
        response.dig(:data, :trial_types)
      else
        Gitlab::AppLogger.warn(
          class: self.class.name,
          message: 'Unable to fetch trial types from GitLab Customers App',
          error_message: response.dig(:data, :errors)
        )

        {}
      end
    end
  end
end
