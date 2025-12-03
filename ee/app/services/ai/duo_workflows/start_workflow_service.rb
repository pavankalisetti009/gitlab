# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class StartWorkflowService
      IMAGE = "registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.5"
      DUO_CLI_VERSION = "8.48.0"
      DWS_STANDARD_CONTEXT_CATEGORY = "agent_platform_standard_context"

      def initialize(workflow:, params:)
        @workflow = workflow
        @current_user = workflow.user
        @service_account = params[:service_account]
        @use_instance_wide_service_account = service_account.nil? && params[:use_service_account]
        @params = params

        @workload_user =
          if service_account.present?
            service_account
          elsif use_instance_wide_service_account
            duo_workflow_service_account
          else
            @current_user
          end
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

        if use_instance_wide_service_account
          response = add_duo_workflow_service_account_to_project
          return ServiceResponse.error(message: response.message, reason: :service_account_error) if response.error?
        end

        link_composite_identity if use_instance_wide_service_account || service_account.present?

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
          workflow_workload = @workflow.workflows_workloads.create(project_id: project.id, workload_id: workload.id)
          unless workflow_workload.persisted?
            return ServiceResponse.error(
              message: workflow_workload.errors.full_messages.join(', '),
              reason: :workflow_workload_failure
            )
          end

          ServiceResponse.success(payload: { workload_id: workload.id })
        else
          ServiceResponse.error(message: response.message, reason: :workload_failure)
        end
      end

      private

      attr_reader :service_account, :use_instance_wide_service_account

      def workload_definition
        ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = @workflow.image.presence || configured_image || IMAGE
          d.variables = variables
          d.commands = commands
          d.cache = cache_configuration if cache_configuration.present?
          if Feature.enabled?(:duo_agent_platform_ci_job_tags, project)
            d.tags = [::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG]
          end
        end
      end

      def configured_image
        return unless project

        duo_config.default_image
      end

      def sandbox
        @sandbox ||= ::Gitlab::DuoWorkflow::Sandbox.new(
          current_user: @current_user,
          duo_workflow_service_url: duo_workflow_service_url
        )
      end

      def sandbox_enabled?
        @workflow.image.blank? && configured_image.blank?
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
        vars[:GIT_FETCH_EXTRA_FLAGS] = "--filter=blob:none"
        vars
      end

      def variables
        base_variables = git_clone_variables.merge(
          DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT: serialized_flow_additional_context,
          DUO_WORKFLOW_BASE_PATH: './',
          DUO_WORKFLOW_DEFINITION: @workflow.workflow_definition,
          DUO_WORKFLOW_FLOW_CONFIG: serialized_duo_flow_config,
          DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION: @params[:flow_config_schema_version],
          DUO_WORKFLOW_GOAL: @params[:goal],
          DUO_WORKFLOW_SOURCE_BRANCH: @params.fetch(:source_branch, nil),
          DUO_WORKFLOW_WORKFLOW_ID: String(@workflow.id),
          GITLAB_OAUTH_TOKEN: @params[:workflow_oauth_token],
          DUO_WORKFLOW_SERVICE_SERVER: duo_workflow_service_url,
          DUO_WORKFLOW_SERVICE_TOKEN: @params[:workflow_service_token],
          DUO_WORKFLOW_SERVICE_REALM: ::CloudConnector.gitlab_realm,
          DUO_WORKFLOW_GLOBAL_USER_ID: Gitlab::GlobalAnonymousId.user_id(@current_user),
          DUO_WORKFLOW_INSTANCE_ID: Gitlab::GlobalAnonymousId.instance_id,
          DUO_WORKFLOW_INSECURE: Gitlab::DuoWorkflow::Client.secure? ? 'false' : 'true',
          DUO_WORKFLOW_DEBUG: Gitlab::DuoWorkflow::Client.debug_mode? ? 'true' : 'false',
          LOG_LEVEL: Gitlab::DuoWorkflow::Client.debug_mode? ? 'debug' : 'info',
          DUO_WORKFLOW_GIT_HTTP_BASE_URL: Gitlab.config.gitlab.url,
          DUO_WORKFLOW_GIT_HTTP_PASSWORD: @params[:workflow_oauth_token],
          GITLAB_TOKEN: @params[:workflow_oauth_token],
          DUO_WORKFLOW_GIT_HTTP_USER: "oauth",
          DUO_WORKFLOW_GIT_USER_EMAIL: git_user_email(@workload_user),
          DUO_WORKFLOW_GIT_USER_NAME: "GitLab Duo",
          DUO_WORKFLOW_METADATA: workflow_metadata,
          DUO_WORKFLOW_PROJECT_ID: project.id,
          DUO_WORKFLOW_NAMESPACE_ID: project.root_namespace.id,
          GITLAB_BASE_URL: Gitlab.config.gitlab.url,
          GITLAB_PROJECT_PATH: project.full_path,
          AGENT_PLATFORM_GITLAB_VERSION: Gitlab.version_info.to_s,
          AGENT_PLATFORM_MODEL_METADATA: agent_platform_model_metadata_json,
          AGENT_PLATFORM_FEATURE_SETTING_NAME: feature_setting_name
        )

        sandbox_enabled? ? base_variables.merge(sandbox.environment_variables) : base_variables
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
        cli_install_commands = [
          %(npm install -g @gitlab/duo-cli@#{DUO_CLI_VERSION}),
          %(ls -la $(npm root -g)/@gitlab/duo-cli || echo "GitLab Duo package not found"),
          %(export PATH="$(npm bin -g):$PATH"),
          %(which duo || echo "duo not in PATH")
        ]

        cli_command = %(duo run --existing-session-id #{@workflow.id} --connection-type #{connection_type})
        wrapped_commands = sandbox_enabled? ? sandbox.wrap_command(cli_command) : [cli_command]

        cli_install_commands + wrapped_commands
      end

      def connection_type
        return "grpc" unless Feature.enabled?(:ai_dap_executor_connects_over_ws, @current_user)

        "websocket"
      end

      def workflow_metadata
        # TODO: This is temporary workaround to pass model selection via
        # metadata into node executor to address
        # https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/issues/1767
        # it will be cleaned up by
        # https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/issues/1630
        ::Gitlab::Json.dump(
          ::Gitlab::Json.parse(@params[:workflow_metadata]).merge(
            'modelMetadata' => agent_platform_model_metadata_json
          )
        )
      end

      def duo_workflow_service_url
        Gitlab::DuoWorkflow::Client.url_for(
          feature_setting: feature_setting,
          user: @current_user
        )
      end

      def duo_workflow_service_account
        ::Ai::Setting.instance.duo_workflow_service_account_user
      end

      def add_duo_workflow_service_account_to_project
        ::Ai::ServiceAccountMemberAddService.new(project, duo_workflow_service_account).execute
      end

      def project
        @workflow.project
      end

      def feature_setting
        @params.fetch(:duo_agent_platform_feature_setting, nil)
      end

      def feature_setting_name
        feature_setting&.feature.to_s
      end

      def agent_platform_model_metadata_json
        response = ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: feature_setting
        ).execute

        response.fetch(Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata::HEADER_KEY, nil)
      end

      def link_composite_identity
        identity = ::Gitlab::Auth::Identity.fabricate(@workload_user)
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
