# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      # This is named ConfigEE to avoid collisions with the
      # EE::Gitlab::Ci::Config namespace
      module ConfigEE
        extend ::Gitlab::Utils::Override

        override :rescue_errors
        def rescue_errors
          [*super, ::Gitlab::Ci::Config::Required::Processor::RequiredError]
        end

        override :build_config
        def build_config(config)
          super
            .then { |config| process_required_includes(config) }
            .then { |config| inject_pipeline_execution_policy_stages(config) }
            .then { |config| process_security_orchestration_policy_includes(config) }
        end

        def process_required_includes(config)
          return config unless required_pipelines_enabled?

          ::Gitlab::Ci::Config::Required::Processor.new(config).perform
        end

        def inject_pipeline_execution_policy_stages(config)
          return config unless pipeline_policy_context&.inject_policy_reserved_stages?

          logger.instrument(:config_pipeline_execution_policy_stages_inject, once: true) do
            ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::ReservedStagesInjector
              .inject_reserved_stages(config)
          end
        end

        def process_security_orchestration_policy_includes(config)
          # We need to prevent SEP jobs from being injected into PEP pipelines
          # because they need to be added into only the main pipeline.
          return config if pipeline_policy_context&.execution_policy_mode?

          logger.instrument(:config_scan_execution_policy_processor, once: true) do
            ::Gitlab::Ci::Config::SecurityOrchestrationPolicies::Processor.new(config, context, source_ref_path,
              source).perform
          end
        end

        def required_pipelines_enabled?
          @project.present? && ::Feature.enabled?(:required_pipelines, @project) # rubocop:disable Gitlab/ModuleWithInstanceVariables -- temporary usage
        end
      end
    end
  end
end
