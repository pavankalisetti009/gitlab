# frozen_string_literal: true

module EE
  module Ci
    module CreatePipelineService
      extend ::Gitlab::Utils::Override

      override :extra_options
      def extra_options(mirror_update: false, **options)
        options.merge(allow_mirror_update: mirror_update)
      end

      private

      override :after_successful_creation_hook
      def after_successful_creation_hook
        super

        ::Onboarding::ProgressTrackingWorker.perform_async(project.namespace_id, 'pipeline_created')
      end

      override :validate_options!
      def validate_options!(options)
        return unless params[:partition_id] && !options[:execution_policy_dry_run]

        raise ArgumentError, "Param `partition_id` is only allowed with `execution_policy_dry_run: true`"
      end
    end
  end
end
