# frozen_string_literal: true

module EE
  module Ci
    module PipelineCreation
      module StartPipelineService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          ::Ci::PipelineCreation::DropNotRunnableBuildsService.new(pipeline).execute

          unless disable_secrets_provider_check_on_pipeline_creation?
            ::Ci::PipelineCreation::DropSecretsProviderNotFoundBuildsService.new(pipeline).execute
          end

          super
        end

        def disable_secrets_provider_check_on_pipeline_creation?
          ::Feature.enabled?(:enable_secrets_provider_check_on_pre_assign_runner_checks, pipeline.project)
        end
      end
    end
  end
end
