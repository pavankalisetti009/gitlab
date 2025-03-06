# frozen_string_literal: true

module Search
  module Zoekt
    class RakeTaskExecutorService
      TASKS = %i[
        info
      ].freeze

      def initialize(logger:)
        @logger = logger
      end

      def execute(task)
        raise ArgumentError, "Unknown task: #{task}" unless TASKS.include?(task)
        raise NotImplementedError unless respond_to?(task, true)

        send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
      end

      private

      attr_reader :logger

      def info
        InfoService.execute(logger: logger)
      end
    end
  end
end
