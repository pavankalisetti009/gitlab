# frozen_string_literal: true

module Search
  module Zoekt
    class RolloutService
      include Gitlab::Loggable

      DEFAULT_OPTIONS = {
        num_replicas: 1,
        max_indices_per_replica: 5,
        dry_run: true,
        batch_size: 128
      }.freeze

      Result = Struct.new(:message, :changes)

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      attr_reader :num_replicas, :max_indices_per_replica, :batch_size, :dry_run

      def initialize(**kwargs)
        options = DEFAULT_OPTIONS.merge(kwargs)
        @num_replicas = options.fetch(:num_replicas)
        @max_indices_per_replica = options.fetch(:max_indices_per_replica)
        @dry_run = options.fetch(:dry_run)
        @batch_size = options.fetch(:batch_size)
      end

      def execute
        resource_pool = ::Search::Zoekt::SelectionService.execute(max_batch_size: batch_size)
        return Result.new('No enabled namespaces found', {}) if resource_pool.enabled_namespaces.empty?
        return Result.new('No available nodes found', {}) if resource_pool.nodes.empty?

        plan = ::Search::Zoekt::PlanningService.plan(
          enabled_namespaces: resource_pool.enabled_namespaces,
          nodes: resource_pool.nodes,
          num_replicas: num_replicas,
          max_indices_per_replica: max_indices_per_replica
        )
        logger.info(build_structured_payload(**{ plan: ::Gitlab::Json.parse(plan.to_json) }))
        return Result.new('Skipping execution of changes because of dry run', {}) if dry_run

        changes = ::Search::Zoekt::ProvisioningService.execute(plan)
        result(changes)
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def result(changes = {})
        success = changes[:success]&.any?
        errors = changes[:errors]&.any?

        message = if success && errors
                    'Batch is completed with partial success'
                  elsif errors
                    'Batch is completed with failure'
                  elsif success
                    'Batch is completed with success'
                  else
                    'Batch is completed without changes'
                  end

        Result.new(message, changes)
      end
    end
  end
end
