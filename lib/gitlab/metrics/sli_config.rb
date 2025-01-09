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

      def self.ee_enabled_classes
        sli_implementations.select(&:ee_only?)
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

        def ee_only!(value = true)
          Gitlab::AppLogger.info "Gitlab::Metrics::SliConfig: marking #{self} as EE-only"
          @ee_only = value # rubocop:disable Gitlab/ModuleWithInstanceVariables -- used to mark if the class importing SliConfig is EE-only
        end

        def ee_only?
          @ee_only
        end
      end

      def self.included(base)
        base.extend(ConfigMethods)
      end
    end
  end
end
