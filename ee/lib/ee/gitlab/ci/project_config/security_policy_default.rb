# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module ProjectConfig
        module SecurityPolicyDefault
          extend ::Gitlab::Utils::Override
          include ::Gitlab::Utils::StrongMemoize

          DUMMY_CONTENT = {
            'Pipeline execution policy trigger' => {
              'stage' => ::Gitlab::Ci::Config::EdgeStagesInjector::PRE_PIPELINE,
              'script' => ['echo "Forcing project pipeline to run policy jobs."']
            }
          }.freeze

          # Scan Execution Policies is a feature that works in parallel with Pipeline Execution Policies.
          # Even if there are PEPs with `override_project_ci`, we want SEPs to still be applied.
          override :content
          def content
            # We merge the security scans with the pipeline configuration in ee/lib/ee/gitlab/ci/config_ee.rb.
            # An empty config with no content is enough to trigger the merge process when the Auto DevOps is disabled
            # and no .gitlab-ci.yml is present.
            if has_applicable_scan_execution_policies_defined?
              YAML.dump(nil)
            elsif has_pipeline_execution_policies_defined?
              # Pipeline execution policy jobs will be merged onto the project pipeline.
              # Create a dummy job to ensure that project pipeline gets created.
              YAML.dump(DUMMY_CONTENT)
            end
          end
          strong_memoize_attr :content

          override :source
          def source
            if has_applicable_scan_execution_policies_defined?
              :security_policies_default_source
            elsif has_pipeline_execution_policies_defined?
              :pipeline_execution_policy_forced
            end
          end
          strong_memoize_attr :source

          private

          attr_reader :pipeline_policy_context

          def has_pipeline_execution_policies_defined?
            pipeline_policy_context&.has_execution_policy_pipelines?
          end

          def has_applicable_scan_execution_policies_defined?
            triggered_for_branch &&
              ::Enums::Ci::Pipeline.ci_and_security_orchestration_sources.key?(pipeline_source) &&
              project.licensed_feature_available?(:security_orchestration_policies) &&
              active_scan_execution_policies?
          end

          def active_scan_execution_policies?
            return false unless ref

            service = ::Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)

            ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations
              .new(project).all
              .to_a
              .flat_map(&:active_scan_execution_policies_for_pipelines)
              .any? { |policy| policy_applicable?(policy) && applicable_for_branch?(service, policy) }
          end

          def policy_applicable?(policy)
            ::Security::SecurityOrchestrationPolicies::PolicyScopeChecker
              .new(project: project)
              .policy_applicable?(policy)
          end

          def applicable_for_branch?(service, policy)
            applicable_branches = service.scan_execution_branches(policy[:rules])

            ref.in?(applicable_branches)
          end
        end
      end
    end
  end
end
