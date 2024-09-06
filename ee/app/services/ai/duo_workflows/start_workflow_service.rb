# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class StartWorkflowService
      def initialize(workflow:, params:)
        @project = workflow.project
        @current_user = workflow.user
        @params = params
      end

      def execute
        return ServiceResponse.error(message: 'Can not start workflow', reason: :not_found) unless Feature.enabled?(
          :duo_workflow, @current_user)

        service = ::Ci::CreatePipelineService.new(@project, @current_user, ref: @project.default_branch_or_main)
        response = service.execute(:duo_workflow, ignore_skip_ci: true, save_on_errors: false,
          content: pipeline_config, variables_attributes: pipeline_variables)
        pipeline = response.payload
        if response.success?
          ServiceResponse.success(payload: { pipeline: pipeline.id }, message: 'Pipeline execution started')
        else
          ServiceResponse.error(message: 'Pipeline creation failed', reason: :bad_request)
        end
      end

      private

      def pipeline_variables
        [
          { key: 'GOAL', secret_value: @params[:goal] },
          { key: 'WORKFLOW_ID', secret_value: String(@params[:workflow_id]) },
          { key: 'GL_TOKEN', secret_value: @params[:workflow_oauth_token] },
          { key: 'DUO_WORKFLOW_SERVICE_SERVER', secret_value: Gitlab::DuoWorkflow::Client.url },
          { key: 'WORKFLOW_SERVICE_TOKEN', secret_value: @params[:workflow_service_token] },
          { key: 'REALM', secret_value: Gitlab::CloudConnector.gitlab_realm },
          { key: 'GIT_STRATEGY', secret_value: 'none' },
          { key: 'GLOBAL_USER_ID', secret_value: Gitlab::GlobalAnonymousId.user_id(@current_user) }
        ]
      end

      def pipeline_config
        {
          image: 'alpine',
          before_script: %{
            apk add curl jq
            response=`curl -L 'https://gitlab.com/api/v4/projects/58711783/releases/permalink/latest'`
            asset_url=`echo "$response" | jq -r '.assets.links.[0].url')`
            $(curl -O $asset_url)
            chmod +x duo-workflow-executor
          },
          run_workflow_executor: {
            artifacts: {
              paths: ['workspace/**/*']
            },
            script: [
              'mkdir workspace',
              './duo-workflow-executor --base-path ./workspace --goal "$GOAL" \
                --workflow-id $WORKFLOW_ID --server $DUO_WORKFLOW_SERVICE_SERVER \
                --duo-workflow-service-token $WORKFLOW_SERVICE_TOKEN \
                --user-id $GLOBAL_USER_ID --realm $REALM \
                --token $GL_TOKEN --base-url $CI_SERVER_URL',
              'echo "Run complete."'
            ]
          }
        }.deep_stringify_keys.to_yaml
      end
    end
  end
end
