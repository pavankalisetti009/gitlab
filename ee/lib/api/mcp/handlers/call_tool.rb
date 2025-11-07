# frozen_string_literal: true

module EE
  module API
    module Mcp
      module Handlers
        module CallTool
          extend ActiveSupport::Concern

          prepended do
            include Gitlab::InternalEventsTracking
          end

          private

          def track_start_event(tool_name, session_id, current_user)
            track_internal_event(
              'start_mcp_tool_call',
              user: current_user,
              namespace: current_user&.namespace,
              additional_properties: {
                session_id: session_id,
                tool_name: tool_name
              }
            )
          end

          def track_finish_event(tool_name, session_id, current_user, success:, error: nil)
            additional_properties = {
              session_id: session_id,
              tool_name: tool_name,
              has_tool_call_success: success.to_s
            }

            if error
              additional_properties[:failure_reason] = error.class.name
              additional_properties[:error_status] = error.message&.truncate(255)
            end

            track_internal_event(
              'finish_mcp_tool_call',
              user: current_user,
              namespace: current_user&.namespace,
              additional_properties: additional_properties
            )
          end
        end
      end
    end
  end
end
