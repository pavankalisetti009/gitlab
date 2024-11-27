# frozen_string_literal: true

# This class encapsulates functionality related to Pipeline Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        OverrideStagesConflictError = Class.new(StandardError)

        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          attr_reader :policy_pipelines, :override_policy_stages

          def initialize(project:, command: nil)
            @project = project
            @command = command # TODO: decouple from this (https://gitlab.com/gitlab-org/gitlab/-/issues/503788)
            @policy_pipelines = []
            @override_policy_stages = []
          end

          def build_policy_pipelines!(partition_id)
            return if creating_policy_pipeline?
            return if policies.empty?

            policies.each do |policy|
              response = create_pipeline(policy, partition_id)
              pipeline = response.payload

              if response.success?
                @policy_pipelines << ::Security::PipelineExecutionPolicy::Pipeline.new(
                  pipeline: pipeline, policy_config: policy)
              elsif pipeline.filtered_as_empty?
                # no-op: we ignore empty pipelines
              elsif block_given?
                yield response.message
              end
            end
          end

          def creating_policy_pipeline?
            current_policy.present?
          end

          def has_execution_policy_pipelines?
            policy_pipelines.present?
          end

          def has_overriding_execution_policy_pipelines?
            return false unless has_execution_policy_pipelines?

            policy_pipelines.any?(&:strategy_override_project_ci?)
          end

          def collect_declared_stages!(new_stages)
            return unless creating_policy_pipeline?
            return unless current_policy.strategy_override_project_ci?

            error = OverrideStagesConflictError.new(
              "Policy `#{current_policy.name}` could not be applied. " \
                "Its stages are incompatible with stages of another `override_project_ci` policy: " \
                "#{override_policy_stages.join(', ')}.")

            if new_stages.size > override_policy_stages.size
              raise error unless stages_compatible?(override_policy_stages, new_stages)

              @override_policy_stages = new_stages
            else
              raise error unless stages_compatible?(new_stages, override_policy_stages)
            end
          end

          # We inject reserved policy stages only when;
          # - creating_policy_pipeline?: This is a temporary pipeline creation mode.
          #   We need to inject these stages for the validation because the policy may use them.
          # - has_execution_policy_pipelines?: This is the actual pipeline creation mode.
          #   It means that the result pipeline will have PEPs.
          #   We need to inject these stages because some of the policies may use them.
          def inject_policy_reserved_stages?
            creating_policy_pipeline? || has_execution_policy_pipelines?
          end

          def valid_stage?(stage)
            return true if creating_policy_pipeline?

            ReservedStagesInjector::STAGES.exclude?(stage)
          end

          private

          attr_reader :project, :command, :current_policy

          def policies
            ::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies.new(project).configs
          end
          strong_memoize_attr :policies

          def create_pipeline(policy, partition_id)
            with_policy_context(policy) do
              ::Ci::CreatePipelineService
                .new(project, command.current_user, ref: command.ref, partition_id: partition_id)
                .execute(command.source,
                  content: policy.content,
                  pipeline_policy_context: self, # propagates itself inside the policy pipeline creation
                  merge_request: command.merge_request, # This is for supporting merge request pipelines
                  ignore_skip_ci: true # We can exit early from `Chain::Skip` by setting this parameter
                  # Additional parameters will be added in https://gitlab.com/gitlab-org/gitlab/-/issues/462004
                )
            end
          end

          # We are setting `@current_policy` to the policy we're currently building the pipeline for.
          # By passing this context into the policy pipeline creation, we can evaluate policy-specific logic from within
          # `CreatePipelineService` by delegating to this object.
          # For example, it allows us to collect declared stages if @current_policy is `override_project_ci`.
          def with_policy_context(policy)
            @current_policy = policy
            yield.tap do
              @current_policy = nil
            end
          end

          # `stages` are considered compatible if they are an ordered subset of `target_stages`.
          # `target_stages` is larger or equally large set of stages.
          # Elements of `stages` must appear in the same order as in `target_stages`.
          # Valid example:
          #   `stages`: [build, deploy]
          #   `target_stages`: [build, test, deploy]
          # Invalid example:
          #   `stages`: [deploy, build]
          #   `target_stages`: [build, test, deploy]
          def stages_compatible?(stages, target_stages)
            stages == target_stages & stages
          end
        end
      end
    end
  end
end
