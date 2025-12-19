# frozen_string_literal: true

# This class encapsulates functionality related to Scan Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module ScanExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          def initialize(project:, ref:, current_user:, source:)
            @project = project
            @ref = ref
            @current_user = current_user
            @source = source
            @injected_job_names_metadata_map = {}
          end

          def has_scan_execution_policies?
            apply_scan_execution_policies? && policies.present?
          end

          def active_scan_execution_actions
            limited_actions = policies.flat_map do |policy|
              limited_actions(policy.actions)
            end.compact

            # If there are multiple SEP policies with the same actions,
            # we may end up with duplicates due to different metadata.
            # Remove the duplicates by comparing all attributes except metadata.
            limited_actions.uniq { |action| action.except(:metadata) }
          end
          strong_memoize_attr :active_scan_execution_actions

          def skip_ci_allowed?
            return true unless has_scan_execution_policies?

            policies.all? { |policy| policy.skip_ci_allowed?(current_user&.id) }
          end

          def collect_injected_job_names_with_metadata(template_with_metadata)
            job_name_with_metadata = extract_job_names_and_metadata(template_with_metadata)
            @injected_job_names_metadata_map.merge!(job_name_with_metadata)
          end

          def job_injected?(name)
            @injected_job_names_metadata_map.key?(name.to_sym)
          end

          def job_options(name)
            return unless job_injected?(name)

            @injected_job_names_metadata_map[name.to_sym]
          end

          private

          attr_reader :project, :ref, :current_user, :source

          def limited_actions(actions)
            action_limit = Gitlab::CurrentSettings.scan_execution_policies_action_limit

            return actions if action_limit == 0

            actions.first(action_limit)
          end

          def apply_scan_execution_policies?
            return false unless project&.feature_available?(:security_orchestration_policies)
            return false unless Enums::Ci::Pipeline.ci_sources.key?(source&.to_sym)

            project.security_policies.type_scan_execution_policy.exists?
          end

          def policies
            return [] if valid_security_orchestration_policy_configurations.blank?

            configurations_with_policies = valid_security_orchestration_policy_configurations
              .filter_map do |configuration|
              [
                configuration,
                configuration.active_pipeline_policies_for_project(ref, project, source)
              ]
            end

            configurations_with_policies.flat_map do |configuration, policies|
              policies.map do |policy|
                ::Security::ScanExecutionPolicy::Config
                  .new(policy: policy, configuration: configuration)
              end
            end
          end
          strong_memoize_attr :policies

          def valid_security_orchestration_policy_configurations
            @valid_security_orchestration_policy_configurations ||=
              ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(project).all
          end

          def extract_job_names_and_metadata(template)
            template
              .except(*Gitlab::Ci::Config::Entry::Root::ALLOWED_KEYS)
              .transform_values { |job_config| job_config.delete(:_metadata) }
          end
        end
      end
    end
  end
end
