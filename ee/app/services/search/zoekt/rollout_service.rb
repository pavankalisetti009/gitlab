# frozen_string_literal: true

module Search
  module Zoekt
    class RolloutService
      DEFAULT_OPTIONS = {
        num_replicas: 1,
        max_indices_per_replica: 5,
        dry_run: true,
        batch_size: 128
      }.freeze

      Result = Struct.new(:success?, :message)

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      attr_reader :num_replicas, :max_indices_per_replica, :batch_size, :dry_run

      def initialize(**kwargs)
        options = DEFAULT_OPTIONS.merge(kwargs)

        @num_replicas = options.fetch(:num_replicas)
        @max_indices_per_replica = options.fetch(:max_indices_per_replica)
        @batch_size = options.fetch(:batch_size)
        @dry_run = options.fetch(:dry_run)

        @logger = options[:logger] if options.has_key?(:logger)
      end

      def execute
        logger.info "Selecting resources"
        resource_pool = ::Search::Zoekt::SelectionService.execute(
          max_batch_size: batch_size
        )

        return failed_result("No enabled namespaces found", logger) if resource_pool.enabled_namespaces.empty?

        return failed_result("No available nodes found", logger) if resource_pool.nodes.empty?

        logger.info "Planning"
        plan = ::Search::Zoekt::PlanningService.plan(
          enabled_namespaces: resource_pool.enabled_namespaces,
          nodes: resource_pool.nodes,
          num_replicas: num_replicas,
          max_indices_per_replica: max_indices_per_replica
        )
        logger.info plan.to_json

        return successful_result("Skipping execution of changes because of dry run", logger) if dry_run

        logger.info "Executing changes"
        changes = ::Search::Zoekt::ProvisioningService.execute(plan)

        return failed_result("Change had an error: #{changes[:errors]}", logger) if changes[:errors].present?

        successful_result("Rollout execution completed successfully", logger)
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def failed_result(message, logger)
        logger.info message
        Result.new(false, message)
      end

      def successful_result(message, logger)
        logger.info message
        Result.new(true, message)
      end
    end
  end
end
