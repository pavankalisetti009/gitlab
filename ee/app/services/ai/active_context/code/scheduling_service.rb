# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class SchedulingService
        include Gitlab::Scheduling::TaskExecutor

        TASKS = {
          saas_initial_indexing: {
            period: 1.hour,
            if: -> { ::Gitlab::Saas.feature_available?(:duo_chat_on_saas) },
            dispatch: { event: SaasInitialIndexingEvent }
          }
        }.freeze

        def self.execute(task)
          new(task).execute
        end

        attr_reader :task

        def initialize(task)
          @task = task.to_sym
        end

        def execute
          raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.include?(task)

          config = TASKS[task]
          execute_config_task(task, config)
        end

        def cache_period
          return unless TASKS.key?(task)

          TASKS[task][:period]
        end
      end
    end
  end
end
