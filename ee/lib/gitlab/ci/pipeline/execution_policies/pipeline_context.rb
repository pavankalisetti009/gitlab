# frozen_string_literal: true

# This class encapsulates functionality related to Scan and Pipeline Execution Policies.
module Gitlab
  module Ci
    module Pipeline
      module ExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          # rubocop:disable Metrics/ParameterLists -- Explicit parameters needed to replace command object delegation
          def initialize(
            project:, source: nil, current_user: nil, ref: nil, sha_context: nil,
            variables_attributes: nil, chat_data: nil, merge_request: nil, schedule: nil, bridge: nil)
            # rubocop:enable Metrics/ParameterLists
            @project = project
            @source = source
            @current_user = current_user
            @ref = ref
            @sha_context = sha_context
            @variables_attributes = variables_attributes
            @chat_data = chat_data
            @merge_request = merge_request
            @schedule = schedule
            @bridge = bridge
          end

          def pipeline_execution_context
            ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext
              .new(
                context: self,
                project: project,
                source: source,
                current_user: current_user,
                ref: ref,
                sha_context: sha_context,
                variables_attributes: variables_attributes,
                chat_data: chat_data,
                merge_request: merge_request,
                schedule: schedule,
                is_parent_pipeline_policy: parent_pipeline_policy?
              )
          end
          strong_memoize_attr :pipeline_execution_context

          def scan_execution_context(ref)
            strong_memoize_with(:scan_execution_context, ref) do
              ::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext.new(
                project: project,
                ref: ref,
                current_user: current_user,
                source: source)
            end
          end

          def skip_ci_allowed?(ref:)
            pipeline_execution_context.skip_ci_allowed? && scan_execution_context(ref).skip_ci_allowed?
          end

          private

          attr_reader :project, :source, :current_user, :ref, :sha_context, :variables_attributes, :chat_data,
            :merge_request, :schedule, :bridge

          def parent_pipeline_policy?
            source&.to_sym == :parent_pipeline && bridge&.source&.to_sym == :pipeline_execution_policy
          end
        end
      end
    end
  end
end
