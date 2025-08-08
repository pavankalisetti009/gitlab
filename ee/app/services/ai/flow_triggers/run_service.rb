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
        flow_definition = fetch_flow_definition
        return unless flow_definition

        workload_definition = ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = flow_definition['image']
          d.commands = flow_definition['commands']
          d.variables = build_variables(params)
        end

        ::Ci::Workloads::RunWorkloadService.new(
          project: project,
          current_user: current_user,
          source: :duo_workflow,
          workload_definition: workload_definition,
          **branch_args
        ).execute
      end

      private

      def fetch_flow_definition
        root_ref = project.repository.root_ref
        flow_definition = project.repository.blob_data_at(root_ref, flow_trigger.config_path)
        return unless flow_definition

        flow_definition = YAML.safe_load(flow_definition)
        return unless flow_definition.is_a?(Hash)

        flow_definition
      rescue Psych::SyntaxError
        nil
      end

      def build_variables(params)
        serialized_resource =
          ::Ai::AiResource::Wrapper.new(current_user, resource).wrap.serialize_for_ai.to_json

        {
          AI_FLOW_CONTEXT: serialized_resource,
          AI_FLOW_INPUT: params[:input],
          AI_FLOW_EVENT: params[:event].to_s
        }
      end

      def branch_args
        args = { create_branch: true }
        args[:source_branch] = resource.source_branch if resource.is_a?(MergeRequest)
        args
      end
    end
  end
end
