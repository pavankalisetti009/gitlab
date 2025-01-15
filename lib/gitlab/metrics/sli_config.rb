# frozen_string_literal: true

module Gitlab
  module Metrics
    module SliConfig
      @puma_enabled_classes = []
      @sidekiq_enabled_classes = []

      def self.puma_enabled_classes
        @puma_enabled_classes
      end

      def self.sidekiq_enabled_classes
        @sidekiq_enabled_classes
      end

      def self.sli_implementations
        @puma_enabled_classes | @sidekiq_enabled_classes
      end

      module ConfigMethods
        def puma_enabled!(value = true)
          return unless value

          Gitlab::AppLogger.info "Gitlab::Metrics::SliConfig: enabling #{self} for Puma"
          SliConfig.puma_enabled_classes << self
        end

        def sidekiq_enabled!(value = true)
          Gitlab::AppLogger.info "Gitlab::Metrics::SliConfig: enabling #{self} for Sidekiq"
          SliConfig.sidekiq_enabled_classes << self if value
        end
      end

      def self.included(base)
        base.extend(ConfigMethods)
      end
    end
  end
end
