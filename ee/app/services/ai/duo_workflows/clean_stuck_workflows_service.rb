# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CleanStuckWorkflowsService
      include ::Services::ReturnServiceResponses
      include ::Gitlab::InternalEventsTracking

      EXPIRATION_IN_MINUTES = 30
      BATCH_LIMIT = 1000

      def execute
        scope = Ai::DuoWorkflows::Workflow.with_status(:created, :running)
                  .stale_since(EXPIRATION_IN_MINUTES.minutes.ago)
        iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

        iterator.each_batch(of: BATCH_LIMIT) do |workflows|
          workflows.to_a.each do |w|
            w.drop

            track_internal_event(
              "cleanup_stuck_agent_platform_session",
              user: w.user,
              project: w.project,
              additional_properties: {
                label: w.workflow_definition,
                value: w.id,
                property: "failed"
              }
            )
          end
        end

        success(:processed)
      end
    end
  end
end
