# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class StartWorkflowService
      IMAGE = 'registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.4'

      def initialize(workflow:, params:)
        @project = workflow.project
        @workflow = workflow
        @current_user = workflow.user
        @params = params
      end

      def execute
        unless @current_user.can?(:execute_duo_workflow_in_ci, @workflow)
          return ServiceResponse.error(message: 'Can not execute workflow in CI',
            reason: :feature_unavailable)
        end

        service = ::Ci::Workloads::RunWorkloadService.new(
          project: @project,
          current_user: @current_user,
          source: :duo_workflow,
          workload_definition: workload_definition,
          create_branch: true
        )
        response = service.execute

        workload = response.payload
        if response.success?
          ServiceResponse.success(payload: { workload_id: workload.id })
        else
          ServiceResponse.error(message: response.message, reason: :workload_failure)
        end
      end

      private

      def workload_definition
        ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = IMAGE
          d.variables = variables
          d.commands = commands
        end
      end

      def variables
        {
          DUO_WORKFLOW_BASE_PATH: './',
          DUO_WORKFLOW_GOAL: @params[:goal],
          DUO_WORKFLOW_WORKFLOW_ID: String(@params[:workflow_id]),
          GITLAB_OAUTH_TOKEN: @params[:workflow_oauth_token],
          DUO_WORKFLOW_SERVICE_SERVER: Gitlab::DuoWorkflow::Client.url,
          DUO_WORKFLOW_SERVICE_TOKEN: @params[:workflow_service_token],
          DUO_WORKFLOW_SERVICE_REALM: ::CloudConnector.gitlab_realm,
          DUO_WORKFLOW_GLOBAL_USER_ID: Gitlab::GlobalAnonymousId.user_id(@current_user),
          DUO_WORKFLOW_INSTANCE_ID: Gitlab::GlobalAnonymousId.instance_id,
          DUO_WORKFLOW_INSECURE: Gitlab::DuoWorkflow::Client.secure? ? 'false' : 'true',
          DUO_WORKFLOW_DEBUG: Gitlab::DuoWorkflow::Client.debug_mode? ? 'true' : 'false',
          DUO_WORKFLOW_GIT_HTTP_BASE_URL: Gitlab.config.gitlab.url,
          DUO_WORKFLOW_GIT_HTTP_PASSWORD: @params[:workflow_oauth_token],
          DUO_WORKFLOW_GIT_HTTP_USER: "oauth",
          GITLAB_BASE_URL: Gitlab.config.gitlab.url
        }
      end

      def commands
        [
          %(echo $DUO_WORKFLOW_DEFINITION),
          %(echo $DUO_WORKFLOW_GOAL),
          %(git checkout $CI_WORKLOAD_REF),
          %(wget #{Gitlab::DuoWorkflow::Executor.executor_binary_url} -O /tmp/duo-workflow-executor.tar.gz),
          %(tar xf /tmp/duo-workflow-executor.tar.gz --directory /tmp),
          %(chmod +x /tmp/duo-workflow-executor),
          %(/tmp/duo-workflow-executor)
        ]
      end
    end
  end
end
