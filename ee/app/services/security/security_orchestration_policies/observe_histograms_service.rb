# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ObserveHistogramsService
      HISTOGRAMS = {
        gitlab_security_policies_scan_execution_configuration_rendering_seconds: {
          description: 'The amount of time to render scan execution policy CI configurations',
          buckets: [1, 3, 5, 10].freeze
        },
        gitlab_security_policies_scan_result_process_duration_seconds: {
          description: 'The amount of time to process scan result policies',
          buckets: [120, 240, 360, 480, 600, 720, 840, 960].freeze
        }
      }.freeze

      class << self
        def measure(name, labels: {}, callback: nil)
          lo = ::Gitlab::Metrics::System.monotonic_time
          ret_val = yield
          hi = ::Gitlab::Metrics::System.monotonic_time
          duration = hi - lo

          histogram(name).observe(labels, duration)

          callback&.call(duration)

          ret_val
        end

        def histogram(name)
          histograms[name] ||= begin
            config = HISTOGRAMS[name] || raise(ArgumentError, "unsupported histogram: #{name}")

            Gitlab::Metrics.histogram(name, config[:description], {}, config[:buckets])
          end
        end

        def histograms
          @histograms ||= {}
        end
      end
    end
  end
end
