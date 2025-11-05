# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class StartWorkflowService
      IMAGE = 'registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.4'
      DWS_STANDARD_CONTEXT_CATEGORY = "agent_platform_standard_context"

      def initialize(workflow:, params:)
        @workflow = workflow
        @current_user = workflow.user
        @params = params
      end

      def execute
        unless @workflow.project_level?
          return ServiceResponse.error(
            message: 'Only project-level workflow is supported',
            reason: :unprocessable_entity)
        end

        unless @current_user.can?(:execute_duo_workflow_in_ci, @workflow)
          return ServiceResponse.error(message: 'Can not execute workflow in CI',
            reason: :feature_unavailable)
        end

        @workload_user = @current_user

        use_service_account = @params.fetch(:use_service_account, false)
        if use_service_account
          response = add_service_account_to_project
          return ServiceResponse.error(message: response.message, reason: :service_account_error) if response.error?

          link_composite_identity
          @workload_user = duo_workflow_service_account
        end

        branch_response = create_workload_branch
        return branch_response unless branch_response.success?

        @ref = branch_response.payload[:branch_name]
        service = ::Ci::Workloads::RunWorkloadService.new(
          project: project,
          current_user: @workload_user,
          source: :duo_workflow,
          workload_definition: workload_definition,
          ref: @ref
        )
        response = service.execute

        if response.success?
          workload = response.payload
          @workflow.workflows_workloads.create(project_id: project.id, workload_id: workload.id)
          ServiceResponse.success(payload: { workload_id: workload.id })
        else
          ServiceResponse.error(message: response.message, reason: :workload_failure)
        end
      end

      private

      def workload_definition
        ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = @workflow.image.presence || configured_image || IMAGE
          d.variables = variables
          d.commands = commands
          d.cache = cache_configuration if cache_configuration.present?
        end
      end

      def configured_image
        return unless project

        duo_config.default_image
      end

      def duo_config
        @duo_config ||= ::Gitlab::DuoAgentPlatform::Config.new(project)
      end

      def cache_configuration
        return unless project

        duo_config.cache_config
      end

      def setup_script_commands
        return [] unless project

        duo_config.setup_script || []
      end

      def git_clone_variables
        vars = {}
        vars[:GIT_DEPTH] = 1 if @params.fetch(:shallow_clone, true)
        vars
      end

      def variables
        git_clone_variables.merge(
          DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT: serialized_flow_additional_context,
          DUO_WORKFLOW_BASE_PATH: './',
          DUO_WORKFLOW_DEFINITION: @workflow.workflow_definition,
          DUO_WORKFLOW_FLOW_CONFIG: serialized_duo_flow_config,
          DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION: @params[:flow_config_schema_version],
          DUO_WORKFLOW_GOAL: @params[:goal],
          DUO_WORKFLOW_SOURCE_BRANCH: @params.fetch(:source_branch, nil),
          DUO_WORKFLOW_WORKFLOW_ID: String(@workflow.id),
          GITLAB_OAUTH_TOKEN: @params[:workflow_oauth_token],
          DUO_WORKFLOW_SERVICE_SERVER: Gitlab::DuoWorkflow::Client.url_for(
            feature_setting: feature_setting,
            user: @current_user
          ),
          DUO_WORKFLOW_SERVICE_TOKEN: @params[:workflow_service_token],

          DUO_WORKFLOW_SERVICE_REALM: ::CloudConnector.gitlab_realm,
          DUO_WORKFLOW_GLOBAL_USER_ID: Gitlab::GlobalAnonymousId.user_id(@current_user),
          DUO_WORKFLOW_INSTANCE_ID: Gitlab::GlobalAnonymousId.instance_id,
          DUO_WORKFLOW_INSECURE: Gitlab::DuoWorkflow::Client.secure? ? 'false' : 'true',
          DUO_WORKFLOW_DEBUG: Gitlab::DuoWorkflow::Client.debug_mode? ? 'true' : 'false',
          DUO_WORKFLOW_GIT_HTTP_BASE_URL: Gitlab.config.gitlab.url,
          DUO_WORKFLOW_GIT_HTTP_PASSWORD: @params[:workflow_oauth_token],
          GITLAB_TOKEN: @params[:workflow_oauth_token],
          DUO_WORKFLOW_GIT_HTTP_USER: "oauth",
          DUO_WORKFLOW_GIT_USER_EMAIL: git_user_email(@workload_user),
          DUO_WORKFLOW_METADATA: @params[:workflow_metadata],
          DUO_WORKFLOW_PROJECT_ID: project.id,
          DUO_WORKFLOW_NAMESPACE_ID: project.root_namespace.id,
          GITLAB_BASE_URL: Gitlab.config.gitlab.url,
          AGENT_PLATFORM_GITLAB_VERSION: Gitlab.version_info.to_s,
          AGENT_PLATFORM_MODEL_METADATA: agent_platform_model_metadata_json
        )
      end

      def commands
        # Prepend setup_script commands to the main commands
        setup_script_commands + main_workflow_commands
      end

      def main_workflow_commands
        [
          %(echo $DUO_WORKFLOW_DEFINITION),
          %(echo $DUO_WORKFLOW_GOAL),
          %(echo $DUO_WORKFLOW_SOURCE_BRANCH),
          %(git checkout $CI_WORKLOAD_REF),
          %(echo $DUO_WORKFLOW_FLOW_CONFIG),
          %(echo $DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION),
          %(echo $DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT),
          %(echo Starting Workflow #{@workflow.id})
        ] + set_up_executor_commands
      end

      def set_up_executor_commands
        if Feature.enabled?(:ai_dap_use_headless_node_executor, @current_user)
          [
            %(npx -y @gitlab/duo-cli@^8.31.0 run --existing-session-id #{@workflow.id})
          ]
        else
          [
            %(wget #{Gitlab::DuoWorkflow::Executor.executor_binary_url} -O /tmp/duo-workflow-executor.tar.gz),
            %(tar xf /tmp/duo-workflow-executor.tar.gz --directory /tmp),
            %(chmod +x /tmp/duo-workflow-executor),
            %(/tmp/duo-workflow-executor)
          ]
        end
      end

      def duo_workflow_service_account
        ::Ai::Setting.instance.duo_workflow_service_account_user
      end

      def add_service_account_to_project
        ::Ai::ServiceAccountMemberAddService.new(project, duo_workflow_service_account).execute
      end

      def project
        @workflow.project
      end

      def feature_setting
        @params.fetch(:duo_agent_platform_feature_setting, nil)
      end

      def agent_platform_model_metadata_json
        response = ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: feature_setting
        ).execute

        response.fetch(Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata::HEADER_KEY, nil)
      end

      def link_composite_identity
        identity = ::Gitlab::Auth::Identity.fabricate(duo_workflow_service_account)
        identity.link!(@current_user) if identity&.composite?
      end

      def serialized_duo_flow_config
        return unless @params[:flow_config].present? && @params[:flow_config].is_a?(Hash)

        ::Gitlab::Json.dump(@params[:flow_config])
      end

      def serialized_flow_additional_context
        context_array = @params[:additional_context] || []

        # Standard context category is controlled by Rails codebase
        # if user provides an envelope with colliding category
        # it should be dropped
        context_array = context_array.delete_if do |envelope|
          envelope[:Category] == DWS_STANDARD_CONTEXT_CATEGORY
        end

        source_branch = @params.fetch(:source_branch, nil)
        primary_branch =
          if project.repository.branch_exists?(source_branch)
            source_branch
          else
            project.default_branch_or_main
          end

        standard_context = {
          "Category" => DWS_STANDARD_CONTEXT_CATEGORY,
          "Content" => ::Gitlab::Json.dump({
            "workload_branch" => @ref,
            "primary_branch" => primary_branch,
            "session_owner_id" => @current_user.id.to_s
          })
        }

        context_array << standard_context
        ::Gitlab::Json.dump(context_array)
      end

      def git_user_email(user)
        return "" unless user.respond_to?(:commit_email_or_default)

        user.commit_email_or_default
      end

      def create_workload_branch
        workload_branch_service = ::Ci::Workloads::WorkloadBranchService.new(
          current_user: @workload_user,
          project: project,
          source_branch: @params.fetch(:source_branch, nil)
        )
        workload_branch_service.execute
      end
    end
  end
end
