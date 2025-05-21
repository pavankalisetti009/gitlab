# frozen_string_literal: true

module Gitlab
  module Metrics
    module Prometheus
      extend ActiveSupport::Concern

      REGISTRY_MUTEX = Mutex.new
      PROVIDER_MUTEX = Mutex.new

      LABKIT_METRICS_ENABLED = ENV.fetch('LABKIT_METRICS_ENABLED', 'false') == 'true'

      class_methods do
        include Gitlab::Utils::StrongMemoize

        # TODO: remove when we move away from Prometheus::Client to Labkit::Metrics::Client completely
        # https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4160
        if LABKIT_METRICS_ENABLED
          def client
            Labkit::Metrics::Client
          end

          def null_metric
            Labkit::Metrics::Null.instance
          end

          def get_metric(metric_type, metric_name, *args)
            Labkit::Metrics::Client.send(metric_type, metric_name, *args) # rubocop:disable GitlabSecurity/PublicSend -- temporary workaround
            # Temporarily dynamically dispatching to avoid creating a long list of client methods.
            # The methods counter, gauge, histogram, summary, will be replaced with Labkit::Metrics::Client.
          end

          def metrics_enabled?
            client.enabled?
          end
        else
          def client
            ::Prometheus::Client
          end

          def null_metric
            NullMetric.instance
          end

          def get_metric(metric_type, metric_name, *args)
            registry.get(metric_name) || registry.method(metric_type).call(metric_name, *args)
          end

          def metrics_enabled?
            !error? && metrics_folder_present?
          end
        end

        def metrics_folder_present?
          multiprocess_files_dir = client.configuration.multiprocess_files_dir

          multiprocess_files_dir &&
            ::Dir.exist?(multiprocess_files_dir) &&
            ::File.writable?(multiprocess_files_dir)
        end

        def prometheus_metrics_enabled?
          strong_memoize(:prometheus_metrics_enabled) do
            prometheus_metrics_enabled_unmemoized
          end
        end

        def reset_registry!
          clear_memoization(:registry)

          REGISTRY_MUTEX.synchronize do
            ::Prometheus::Client.cleanup!
            client.reset!
          end
        end

        def registry
          strong_memoize(:registry) do
            REGISTRY_MUTEX.synchronize do
              strong_memoize(:registry) do
                ::Prometheus::Client.registry
              end
            end
          end
        end

        def counter(name, docstring, base_labels = {})
          safe_provide_metric(:counter, name, docstring, base_labels)
        end

        def summary(name, docstring, base_labels = {})
          safe_provide_metric(:summary, name, docstring, base_labels)
        end

        def gauge(name, docstring, base_labels = {}, multiprocess_mode = :all)
          safe_provide_metric(:gauge, name, docstring, base_labels, multiprocess_mode)
        end

        def histogram(name, docstring, base_labels = {}, buckets = ::Prometheus::Client::Histogram::DEFAULT_BUCKETS)
          safe_provide_metric(:histogram, name, docstring, base_labels, buckets)
        end

        # TODO: remove when we move away from Prometheus::Client to Labkit::Metrics::Client completely
        # https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4160
        def error_detected!
          set_error!(true)
          Labkit::Metrics::Client.disable!
        end

        # Used only in specs to reset the error state
        #
        # TODO: remove when we move away from Prometheus::Client to Labkit::Metrics::Client completely
        # https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4160
        def clear_errors!
          set_error!(false)
          Labkit::Metrics::Client.enable!
        end

        def set_error!(status)
          clear_memoization(:prometheus_metrics_enabled)

          PROVIDER_MUTEX.synchronize do
            @error = status
          end
        end

        private

        def safe_provide_metric(metric_type, metric_name, *args)
          PROVIDER_MUTEX.synchronize do
            provide_metric(metric_type, metric_name, *args)
          end
        end

        def provide_metric(metric_type, metric_name, *args)
          if prometheus_metrics_enabled?
            get_metric(metric_type, metric_name, *args)
          else
            null_metric
          end
        end

        def prometheus_metrics_enabled_unmemoized
          (metrics_enabled? && Gitlab::CurrentSettings.prometheus_metrics_enabled) || false
        end
      end
    end
  end
end
