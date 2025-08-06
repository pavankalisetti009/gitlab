# frozen_string_literal: true

module GitlabSubscriptions
  class TrialDurationService
    include ReactiveCaching

    DEFAULT_DURATIONS = {
      GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: 30 },
      GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE => { duration_days: 60 }
    }.freeze

    attr_reader :trial_type

    self.reactive_cache_key = ->(_record) { model_name.singular }
    self.reactive_cache_refresh_interval = 1.hour
    self.reactive_cache_lifetime = 1.hour
    self.reactive_cache_work_type = :external_dependency
    self.reactive_cache_worker_finder = ->(trial_type, *_args) { new(trial_type) }

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

    # Required for ReactiveCaching
    def id
      trial_type
    end

    private

    def find_trial_types
      with_reactive_cache { |data| data } || {}
    end

    def default_duration
      DEFAULT_DURATIONS[trial_type] || DEFAULT_DURATIONS[GitlabSubscriptions::Trials::FREE_TRIAL_TYPE]
    end

    def calculate_reactive_cache
      trial_types_request
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
