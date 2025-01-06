# frozen_string_literal: true

# This class is the object representation of a single entry in the policy.yml
module Security
  module ScanExecutionPolicy
    class Config
      attr_reader :actions

      def initialize(policy:)
        @actions = policy.fetch(:actions)
      end
    end
  end
end
