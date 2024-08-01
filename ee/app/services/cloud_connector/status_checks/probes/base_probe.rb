# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class BaseProbe
        def execute(**_context)
          raise "#{self.class} must implement #execute"
        end

        private

        def success(message)
          ProbeResult.new(probe_name, true, message)
        end

        def failure(message)
          ProbeResult.new(probe_name, false, message)
        end

        def probe_name
          self.class.name.demodulize.underscore.to_sym
        end
      end
    end
  end
end
