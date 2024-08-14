# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Variables
        module Builder
          class ScanExecutionPolicies
            include ::Gitlab::Utils::StrongMemoize

            attr_reader :project, :pipeline

            def initialize(pipeline)
              @pipeline = pipeline
              @project = pipeline.project
            end

            def variables(job_name, job_user)
              ::Gitlab::Ci::Variables::Collection.new.tap do |variables|
                next variables unless enforce_scan_execution_policies_variables?(job_name)

                variables_for_job(job_name, job_user).each do |key, value|
                  variables.append(key: key, value: value.to_s)
                end
              end
            end

            private

            def enforce_scan_execution_policies_variables?(job_name)
              return false if job_name.blank?

              project.licensed_feature_available?(:security_orchestration_policies)
            end

            def variables_for_job(job_name, job_user)
              active_scan_variables(job_user)[job_name.to_sym] || []
            end

            def active_scan_variables(job_user)
              strong_memoize_with(:active_scan_variables, project) do
                ci_configs = ::Security::SecurityOrchestrationPolicies::ScanPipelineService.new(ci_context(job_user))
                                                                                           .execute(active_scan_actions)
                ci_configs[:variables]
              end
            end

            def active_scan_actions
              return [] if security_orchestration_policy_configurations.blank?

              security_orchestration_policy_configurations
                .flat_map { |config| config.active_policies_scan_actions_for_project(pipeline.jobs_git_ref, project) }
                .compact
                .uniq
            end

            def security_orchestration_policy_configurations
              ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(project).all
            end
            strong_memoize_attr :security_orchestration_policy_configurations

            def ci_context(job_user)
              ::Gitlab::Ci::Config::External::Context.new(project: project, user: job_user)
            end
          end
        end
      end
    end
  end
end
