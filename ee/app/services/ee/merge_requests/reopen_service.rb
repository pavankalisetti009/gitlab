# frozen_string_literal: true

module EE
  module MergeRequests
    module ReopenService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(merge_request)
        super.tap do
          delete_approvals(merge_request)

          if current_user.project_bot?
            log_audit_event(merge_request, 'merge_request_reopened_by_project_bot',
              "Reopened merge request #{merge_request.title}")
          end

          publish_event(merge_request)
        end
      end

      private

      def publish_event(merge_request)
        ::Gitlab::EventStore.publish(
          ::MergeRequests::ReopenedEvent.new(data: {
            merge_request_id: merge_request.id
          })
        )
      end
    end
  end
end
