# frozen_string_literal: true

module Gitlab
  module ConditionalConcurrencyLimitControl
    DEFAULT_RESCHEDULE_INTERVAL = 5.seconds

    def perform(*args)
      if defer_job?(*args)
        self.class.perform_in(reschedule_interval, *args)
      else
        super
      end
    end

    private

    def defer_job?(*args)
      return super if defined?(super)

      false
    end

    def reschedule_interval
      return super if defined?(super)

      DEFAULT_RESCHEDULE_INTERVAL
    end
  end
end
