# frozen_string_literal: true

module Gitlab
  module Metrics
    module SliConfig
      def self.registered_classes
        @registered_classes ||= []
      end

      def self.enabled_slis
        @enabled_slis ||= SliConfig.registered_classes.filter_map(&:call)
      end

      # reset_slis! is a helper method to clear the evaluated SLI classes for testing purposes only
      def self.reset_slis!
        @enabled_slis = nil
      end

      def self.register(klass, is_runtime_enabled)
        SliConfig.registered_classes << -> do
          return unless is_runtime_enabled.call

          Gitlab::AppLogger.info "Gitlab::Metrics::SliConfig: enabling #{self}"
          klass
        end
      end

      module ConfigMethods
        def puma_enabled!(enable = true)
          is_runtime_enabled = -> { enable && Gitlab::Runtime.puma? }
          SliConfig.register(self, is_runtime_enabled)
        end

        def sidekiq_enabled!(enable = true)
          is_runtime_enabled = -> { enable && Gitlab::Runtime.sidekiq? }
          SliConfig.register(self, is_runtime_enabled)
        end
      end

      def self.included(base)
        base.extend(ConfigMethods)
      end
    end
  end
end
