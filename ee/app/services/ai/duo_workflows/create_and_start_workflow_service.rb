# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateAndStartWorkflowService
      include ::Gitlab::Utils::StrongMemoize

      MISSING_WORKFLOW_TOKEN_ERROR = 'Could not obtain Duo Workflow token'
      MISSING_OAUTH_TOKEN_ERROR = 'Could not obtain authentication token'
      MISSING_WORKFLOW_DEFINITION_ERROR = 'Workflow definition cannot be blank'
      MISSING_SOURCE_BRANCH_ERROR = 'Source branch cannot be blank'

      DEFAULT_ENVIRONMENT = 'web'
      DEFAULT_WORKFLOW_PARAMS = {
        environment: DEFAULT_ENVIRONMENT,
        allow_agent_to_request_user: false
      }.freeze

      def initialize(container:, current_user:, goal:, source_branch:, workflow_definition:, workflow_params: {})
        @container = container
        @current_user = current_user
        @goal = goal
        @source_branch = source_branch
        @workflow_definition = workflow_definition
        @workflow_params = workflow_params
      end

      def execute
        return validation if validation.error?

        create_result = ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: container,
          current_user: current_user,
          params: create_workflow_params
        ).execute

        return error(create_result.message, :create_workflow) if create_result.error?

        workflow = create_result[:workflow]

        start_result = ::Ai::DuoWorkflows::StartWorkflowService.new(
          workflow: workflow,
          params: start_workflow_params(workflow)
        ).execute

        return error(start_result.message, :start_workflow) if start_result.error?

        workload_id = start_result.payload[:workload_id]
        message = start_result.message

        ServiceResponse.success(message: message, payload: { workflow_id: workflow.id, workload_id: workload_id })
      end

      private

      attr_reader :container, :current_user, :workflow_definition, :goal, :source_branch, :workflow_params

      def validation
        return error(MISSING_WORKFLOW_DEFINITION_ERROR, :invalid_workflow_definition) if workflow_definition.blank?
        return error(MISSING_SOURCE_BRANCH_ERROR, :invalid_source_branch) if source_branch.blank?
        return error(MISSING_WORKFLOW_TOKEN_ERROR, :invalid_duo_workflow_token) if workflow_service_token.nil?
        return error(MISSING_OAUTH_TOKEN_ERROR, :invalid_oauth_token) if workflow_oauth_token.nil?

        ServiceResponse.success
      end
      strong_memoize_attr :validation

      def error(message, reason, payload = {})
        ServiceResponse.error(message: message, reason: reason, payload: payload)
      end

      def workflow_context_generation_service
        ::Ai::DuoWorkflows::WorkflowContextGenerationService.new(
          current_user: current_user,
          organization: container.organization,
          container: container,
          workflow_definition: workflow_definition
        )
      end
      strong_memoize_attr :workflow_context_generation_service

      def create_workflow_params
        workflow_params
          .reverse_merge(
            goal: goal,
            workflow_definition: workflow_definition,
            **DEFAULT_WORKFLOW_PARAMS
          ).compact
      end

      def start_workflow_params(workflow)
        {
          goal: goal,
          workflow_definition: workflow_definition,
          workflow_id: workflow.id,
          workflow_oauth_token: workflow_oauth_token,
          workflow_service_token: workflow_service_token,
          use_service_account: workflow_context_generation_service.use_service_account?,
          source_branch: source_branch,
          workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user).to_json,
          duo_agent_platform_feature_setting: workflow_context_generation_service.duo_agent_platform_feature_setting
        }
      end

      def workflow_service_token
        workflow_token_result = workflow_context_generation_service.generate_workflow_token
        return if workflow_token_result.error?

        workflow_token_result.payload.fetch(:token)
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        nil
      end
      strong_memoize_attr :workflow_service_token

      def workflow_oauth_token
        oauth_token_result = workflow_context_generation_service.generate_oauth_token_with_composite_identity_support
        return if oauth_token_result.error?

        oauth_token_result.payload.fetch(:oauth_access_token).plaintext_token
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        nil
      end
      strong_memoize_attr :workflow_oauth_token
    end
  end
end
