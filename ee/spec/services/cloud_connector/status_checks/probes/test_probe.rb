# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      # Returns a canned response, useful for unit testing.
      class TestProbe < BaseProbe
        def initialize(success: true)
          @success = success
        end

        def execute(*)
          return failure('NOK') unless @success

          success('OK')
        end
      end
    end
  end
end
