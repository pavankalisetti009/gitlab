# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class SchedulingService
        include Gitlab::Scheduling::TaskExecutor

        TASKS = {
          # Example task format (no actual tasks yet):
          # example_task: {
          #   period: 1.hour,
          #   if: -> { SomeCondition.met? },
          #   dispatch: { event: SomeEvent }
          # },
          # another_example: {
          #   if: -> { AnotherCondition.exists? },
          #   execute: -> { SomeService.execute }
          # }
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
