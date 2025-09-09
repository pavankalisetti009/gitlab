# frozen_string_literal: true

module Ai
  module FlowTriggers
    class RunService
      attr_reader :project, :current_user, :resource, :flow_trigger

      def initialize(project:, current_user:, resource:, flow_trigger:)
        @project = project
        @current_user = current_user
        @resource = resource
        @flow_trigger = flow_trigger
      end

      def execute(params)
        # Create Duo Workflow Header
        wf_create_result = ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: project,
          current_user: current_user,
          params: {
            workflow_definition: "Trigger - #{flow_trigger.description}",
            status: :running,
            goal: params[:input],
            environment: :web
          }
        ).execute

        return ServiceResponse.error(message: wf_create_result[:message]) if wf_create_result.error?

        workflow = wf_create_result[:workflow]
        params[:flow_id] = workflow.id

        note_service = ::Ai::FlowTriggers::CreateNoteService.new(
          project: project, resource: resource, author: flow_trigger.user, discussion: params[:discussion]
        )

        note_service.execute(params) do |updated_params|
          run_workload(updated_params, workflow)
        end
      end

      private

      def run_workload(params, workflow)
        flow_definition = fetch_flow_definition
        return ServiceResponse.error(message: 'invalid or missing flow definition') unless flow_definition

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

        result = ::Ci::Workloads::RunWorkloadService.new(
          project: project,
          current_user: flow_trigger.user,
          source: :duo_workflow,
          workload_definition: workload_definition,
          ci_variables_included: flow_definition['variables'] || [],
          **branch_args
        ).execute

        status_event = result.success? ? "start" : "drop"

        ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
          workflow: workflow, status_event: status_event, current_user: current_user
        ).execute

        workflow.workflows_workloads.create(project_id: project.id, workload_id: result.payload.id)

        result
      end

      def fetch_flow_definition
        root_ref = project.repository.root_ref
        flow_definition = project.repository.blob_data_at(root_ref, flow_trigger.config_path)
        return unless flow_definition

        flow_definition = YAML.safe_load(flow_definition)
        return unless flow_definition.is_a?(Hash)

        flow_definition
      rescue Psych::Exception
        nil
      end

      def build_variables(params)
        serialized_resource =
          ::Ai::AiResource::Wrapper.new(current_user, resource).wrap.serialize_for_ai.to_json

        base_variables = {
          AI_FLOW_CONTEXT: serialized_resource,
          AI_FLOW_INPUT: params[:input],
          AI_FLOW_EVENT: params[:event].to_s,
          AI_FLOW_DISCUSSION_ID: params[:discussion_id],
          AI_FLOW_ID: params[:flow_id]
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
    end
  end
end
