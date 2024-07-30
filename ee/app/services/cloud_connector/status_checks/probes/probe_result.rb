# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class ProbeResult
        attr_reader :name, :success, :message

        def initialize(name, success, message)
          @name = name
          @success = success
          @message = message
        end

        def success?
          !!@success
        end
      end
    end
  end
end
