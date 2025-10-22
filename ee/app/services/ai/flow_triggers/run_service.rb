# frozen_string_literal: true

module Ai
  module FlowTriggers
    class RunService
      include ::Gitlab::Utils::StrongMemoize

      def initialize(project:, current_user:, resource:, flow_trigger:)
        @project = project
        @current_user = current_user
        @resource = resource
        @flow_trigger = flow_trigger
        @flow_trigger_user = flow_trigger.user
        @catalog_item = flow_trigger.ai_catalog_item_consumer&.item
        @catalog_item_pinned_version = flow_trigger.ai_catalog_item_consumer&.pinned_version_prefix

        link_composite_identity! if can_use_composite_identity?
      end

      def execute(params)
        return validation_error if validation_error

        note_service = ::Ai::FlowTriggers::CreateNoteService.new(
          project: project, resource: resource, author: flow_trigger_user, discussion: params[:discussion]
        )

        note_service.execute(params) do |updated_params|
          if catalog_item&.flow?
            start_catalog_workflow(params)
          else
            run_workload(updated_params)
          end
        end
      end

      private

      strong_memoize_attr def validation_error
        return ServiceResponse.error(message: 'cannot be triggered by non-human users') unless current_user.human?

        return unless catalog_item&.third_party_flow? && Feature.disabled?(:ai_catalog_third_party_flows, current_user)

        ServiceResponse.error(message: 'ai_catalog_third_party_flows feature flag is not enabled')
      end

      attr_reader :project, :current_user, :resource, :flow_trigger, :flow_trigger_user,
        :catalog_item, :catalog_item_pinned_version

      def run_workload(params)
        flow_definition = fetch_flow_definition
        return ServiceResponse.error(message: 'invalid or missing flow definition') unless flow_definition

        workflow_params = {
          workflow_definition: "Trigger - #{flow_trigger.description}",
          status: :running,
          goal: params[:input],
          environment: :web
        }

        wf_create_result = ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: project,
          current_user: current_user,
          params: workflow_params
        ).execute

        return ServiceResponse.error(message: wf_create_result[:message]) if wf_create_result.error?

        workflow = wf_create_result[:workflow]

        if flow_definition['injectGatewayToken'] == true
          token_response = ::Ai::ThirdPartyAgents::TokenService.new(current_user: current_user).direct_access_token
          return token_response if token_response.error?

          params[:token] = token_response.payload
        end

        workload_definition = ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = flow_definition['image']
          d.commands = flow_definition['commands']
          d.variables = build_variables(params)
        end

        response = ::Ci::Workloads::RunWorkloadService.new(
          project: project,
          current_user: flow_trigger_user,
          source: :duo_workflow,
          workload_definition: workload_definition,
          ci_variables_included: flow_definition['variables'] || [],
          **branch_args
        ).execute

        if response.success?
          workflow.workflows_workloads.create(project_id: project.id,
            workload_id: response.payload.id)
        end

        status_event = response.success? ? "start" : "drop"
        ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
          workflow: workflow, status_event: status_event, current_user: current_user
        ).execute

        [response, workflow]
      end

      def start_catalog_workflow(params)
        response = ::Ai::Catalog::Flows::ExecuteService.new(
          project: project,
          current_user: current_user,
          params: {
            flow: catalog_item,
            flow_version: catalog_item.resolve_version(catalog_item_pinned_version),
            event_type: params[:event].to_s,
            user_prompt: catalog_item_user_prompt(params[:input]),
            execute_workflow: true
          }
        ).execute

        workflow = response.payload[:workflow]

        [response, workflow]
      end

      def fetch_flow_definition
        return catalog_item.definition(catalog_item_pinned_version) if catalog_item&.third_party_flow?

        root_ref = project.repository.root_ref
        flow_definition_yaml = project.repository.blob_data_at(root_ref, flow_trigger.config_path)
        return unless flow_definition_yaml

        flow_definition = YAML.safe_load(flow_definition_yaml)
        return unless flow_definition.is_a?(Hash)

        flow_definition
      rescue Psych::Exception
        nil
      end

      def build_variables(params)
        base_variables = {
          AI_FLOW_CONTEXT: serialized_resource,
          AI_FLOW_DISCUSSION_ID: params[:discussion_id],
          AI_FLOW_EVENT: params[:event].to_s,
          AI_FLOW_GITLAB_TOKEN: composite_identity_token,
          AI_FLOW_INPUT: params[:input]
        }

        if params.key?(:token)
          gateway_token = params[:token]

          headers_string = if gateway_token[:headers].present?
                             gateway_token[:headers].map { |k, v| "#{k}: #{v}" }.join("\n")
                           else
                             ''
                           end

          base_variables.merge!({
            AI_FLOW_AI_GATEWAY_TOKEN: gateway_token[:token],
            AI_FLOW_AI_GATEWAY_HEADERS: headers_string
          })
        end

        base_variables
      end

      def branch_args
        args = { create_branch: true }
        args[:source_branch] = resource.source_branch if resource.is_a?(MergeRequest)
        args
      end

      def composite_identity_token
        return unless can_use_composite_identity?

        composite_oauth_token_result = ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService.new(
          current_user: current_user,
          organization: project.organization,
          scopes: ['api'],
          service_account: flow_trigger_user
        ).execute

        return if composite_oauth_token_result.error?

        composite_oauth_token_result[:oauth_access_token].plaintext_token
      end

      def can_use_composite_identity?
        return false unless current_user
        return false unless Feature.enabled?(:ai_flow_triggers_use_composite_identity, current_user)
        return false if Ai::Setting.instance.duo_workflow_oauth_application.nil?

        flow_trigger_user.composite_identity_enforced?
      end

      def link_composite_identity!
        identity = ::Gitlab::Auth::Identity.fabricate(flow_trigger_user)
        identity.link!(current_user) if identity&.composite?
      end

      def serialized_resource
        ::Ai::AiResource::Wrapper.new(current_user, resource).wrap.serialize_for_ai.to_json
      end

      # Pass the user input and the current context as a user prompt to a catalog item
      # Ideally, it should be prompt variables for better flexibility
      def catalog_item_user_prompt(user_input)
        "Input: #{user_input}\nContext: #{serialized_resource}"
      end
    end
  end
end
