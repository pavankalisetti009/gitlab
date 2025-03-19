# frozen_string_literal: true

module Search
  module Zoekt
    class ProvisioningService
      def self.execute(plan)
        new(plan).execute
      end

      attr_reader :plan, :errors

      def initialize(plan)
        @plan = plan
        @errors = []
      end

      def execute
        ApplicationRecord.transaction do
          plan[:namespaces].each do |namespace_plan|
            next if namespace_plan[:errors].present?

            process_namespace(namespace_plan)
          end
        end
        { errors: @errors }
      rescue StandardError => e
        log_error(:transaction_failed, e.message, e.backtrace)
        { errors: @errors }
      end

      private

      def process_namespace(namespace_plan)
        namespace_id = namespace_plan.fetch(:namespace_id)
        enabled_namespace_id = namespace_plan.fetch(:enabled_namespace_id)

        # Remove any pre-existing replicas for this namespace since we are provisioning new ones.
        enabled_namespace = Search::Zoekt::EnabledNamespace.for_root_namespace_id(namespace_id).first
        if enabled_namespace.nil?
          log_error(:missing_enabled_namespace, "Enabled namespace not found for namespace ID: #{namespace_id}")
          return
        end

        enabled_namespace.replicas.delete_all

        if Index.for_root_namespace_id(namespace_id).exists?
          log_error(:index_already_exists, "Indices already exists for namespace ID: #{namespace_id}")
          return
        end

        namespace_plan[:replicas].each do |replica_plan|
          process_replica(
            namespace_id: namespace_id,
            enabled_namespace_id: enabled_namespace_id,
            replica_plan: replica_plan
          )
        end
      end

      def process_replica(namespace_id:, enabled_namespace_id:, replica_plan:)
        replica = Replica.create!(namespace_id: namespace_id, zoekt_enabled_namespace_id: enabled_namespace_id)

        replica_plan[:indices].each do |index_plan|
          process_index(replica, index_plan)
        end
      end

      def process_index(replica, index_plan)
        node = Node.find(index_plan[:node_id])
        required_storage_bytes = index_plan[:required_storage_bytes]

        if required_storage_bytes > node.unclaimed_storage_bytes
          log_error(
            :node_capacity_exceeded,
            "Node #{node.id} has #{node.unclaimed_storage_bytes} unclaimed storage bytes and " \
              "cannot fit #{required_storage_bytes} bytes."
          )
          return
        end

        Index.create!(
          replica: replica,
          zoekt_enabled_namespace_id: replica.zoekt_enabled_namespace_id,
          namespace_id: replica.namespace_id,
          zoekt_node_id: node.id,
          reserved_storage_bytes: required_storage_bytes,

          # Workaround: we remove nil project_namespace_id_to since it is not a valid property in json validator.
          metadata: index_plan[:projects].compact
        )

        update_node_storage(node, required_storage_bytes)
      end

      def update_node_storage(node, used_bytes)
        node.update!(used_bytes: node.used_bytes + used_bytes)
      end

      def log_error(message, details, trace = [])
        err = {
          class: self.class.name,
          message: message,
          details: details,
          trace: trace.slice(0, 5)
        }

        @errors << err

        logger.error(**err)
      end

      def logger
        @logger ||= Search::Zoekt::Logger.build
      end
    end
  end
end
