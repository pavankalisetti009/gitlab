# frozen_string_literal: true

module Ai
  module DuoWorkflows
    # rubocop: disable Scalability/IdempotentWorker -- EventStore::Subscriber includes idempotent
    class UpdateWorkflowStatusEventWorker
      include Gitlab::EventStore::Subscriber

      feature_category :duo_agent_platform
      data_consistency :delayed

      def handle_event(event)
        workload = Ci::Workloads::Workload.find_by_id(event.data[:workload_id])
        return unless workload

        workflow = workload.workflows.last
        return unless workflow

        action = event.data[:status].to_sym == :finished ? 'finish' : 'drop'
        UpdateWorkflowStatusService.new(workflow: workflow, status_event: action, current_user: workflow.user).execute
      end
    end
    # rubocop: enable Scalability/IdempotentWorker
  end
end
