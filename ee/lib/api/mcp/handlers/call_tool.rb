# frozen_string_literal: true

module API
  module Mcp
    module Handlers
      class CallTool
        include Gitlab::InternalEventsTracking

        def initialize(manager)
          @manager = manager
        end

        def invoke(request, params, current_user = nil)
          tool_name = params[:name]
          session_id = request[:id] || SecureRandom.uuid

          track_start_event(tool_name, session_id, current_user)

          tool = fetch_tool(tool_name, session_id, current_user)
          configure_tool_credentials(tool, current_user)
          execute_tool_with_tracking(tool, request, params, tool_name, session_id, current_user)
        end

        private

        attr_reader :manager

        def fetch_tool(tool_name, session_id, current_user)
          manager.get_tool(name: tool_name)
        rescue ::Mcp::Tools::Manager::ToolNotFoundError => e
          track_finish_event(tool_name, session_id, current_user, success: false, error: e)
          raise ArgumentError, e.message
        end

        def configure_tool_credentials(tool, current_user)
          tool.set_cred(current_user: current_user) if tool.is_a?(::Mcp::Tools::CustomService)
        end

        def execute_tool_with_tracking(tool, request, params, tool_name, session_id, current_user)
          result = tool.execute(request: request, params: params)
          track_finish_event(tool_name, session_id, current_user, success: true)
          result
        rescue StandardError => error
          track_finish_event(tool_name, session_id, current_user, success: false, error: error)
          raise error
        end

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
