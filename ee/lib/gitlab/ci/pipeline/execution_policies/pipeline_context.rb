# frozen_string_literal: true

# This class encapsulates functionality related to Scan and Pipeline Execution Policies.
module Gitlab
  module Ci
    module Pipeline
      module ExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          def initialize(project:, command: nil)
            @project = project
            @command = command # TODO: decouple from this (https://gitlab.com/gitlab-org/gitlab/-/issues/503788)
          end

          delegate :policy_pipelines, :override_policy_stages, :build_policy_pipelines!, :creating_policy_pipeline?,
            :has_execution_policy_pipelines?, :has_overriding_execution_policy_pipelines?, :collect_declared_stages!,
            :inject_policy_reserved_stages?, :valid_stage?, to: :pipeline_execution_context

          def pipeline_execution_context
            ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext
              .new(context: self, project: project, command: command)
          end
          strong_memoize_attr :pipeline_execution_context

          def skip_ci_allowed?
            !has_execution_policy_pipelines?
          end

          private

          attr_reader :project, :command
        end
      end
    end
  end
end
