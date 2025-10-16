# frozen_string_literal: true

module Ai
  module Catalog
    class ExecuteWorkflowService
      include Gitlab::Utils::StrongMemoize

      FLOW_CONFIG_VERSION = 'experimental'
      WORKFLOW_ENVIRONMENT = 'web'
      AGENT_PRIVILEGES = [
        DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
        DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
        DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
        DuoWorkflows::Workflow::AgentPrivileges::USE_GIT,
        DuoWorkflows::Workflow::AgentPrivileges::RUN_MCP_TOOLS
      ].freeze

      def initialize(current_user, params)
        @current_user = current_user
        @json_config = params[:json_config]
        @container = params[:container]
        @goal = params[:goal]
        @item_version = params[:item_version]
      end

      def execute
        return validate unless validate.success?

        workflow_result = create_workflow
        return error(workflow_result[:message]) if workflow_result.error?

        workflow = workflow_result.payload[:workflow]

        start_result = start_workflow_execution(workflow)
        return error(start_result[:message]) if start_result.error?

        ServiceResponse.success(
          payload: {
            workflow: workflow,
            workload_id: start_result.payload[:workload_id],
            flow_config: json_config.to_yaml
          }
        )
      end

      private

      attr_reader :current_user, :json_config, :container, :goal, :item_version

      def error(message, payload: {})
        ServiceResponse.error(message: Array(message), payload: payload)
      end

      def validate
        return error('You have insufficient permissions') unless allowed?
        return error('JSON config is required') unless json_config.present?
        return error('Goal is required') unless goal.present?

        ServiceResponse.success
      end
      strong_memoize_attr :validate

      def create_workflow
        workflow_params = {
          goal: goal,
          workflow_definition: determine_workflow_definition,
          environment: WORKFLOW_ENVIRONMENT,
          agent_privileges: AGENT_PRIVILEGES,
          pre_approved_agent_privileges: AGENT_PRIVILEGES
        }

        ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: container,
          current_user: current_user,
          params: workflow_params
        ).execute
      end

      def start_workflow_execution(workflow)
        start_params = build_start_workflow_params(workflow)
        return start_params if start_params.is_a?(ServiceResponse) && start_params.error?

        ::Ai::DuoWorkflows::StartWorkflowService.new(
          workflow: workflow,
          params: start_params
        ).execute
      end

      def build_start_workflow_params(workflow)
        token_service = token_generation_service

        oauth_token_result = token_service.generate_oauth_token_with_composite_identity_support
        return oauth_token_result if oauth_token_result.error?

        workflow_token_result = token_service.generate_workflow_token
        return workflow_token_result if workflow_token_result.error?

        {
          goal: goal,
          flow_config: json_config,
          flow_config_schema_version: FLOW_CONFIG_VERSION,
          workflow_id: workflow.id,
          workflow_oauth_token: oauth_token_result.payload[:oauth_access_token].plaintext_token,
          workflow_service_token: workflow_token_result.payload[:token],
          use_service_account: token_service.use_service_account?,
          source_branch: nil,
          workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user).to_json
        }
      end

      def token_generation_service
        ::Ai::DuoWorkflows::TokenGenerationService.new(
          current_user: current_user,
          organization: container.organization,
          container: container,
          workflow_definition: determine_workflow_definition
        )
      end

      def determine_workflow_definition
        'ai_catalog_agent'
      end

      def allowed?
        Ability.allowed?(current_user, :execute_ai_catalog_item_version, item_version)
      end
    end
  end
end
