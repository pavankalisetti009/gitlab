# frozen_string_literal: true

module EE
  module Ci
    module CancelPipelineService
      extend ::Gitlab::Utils::Override

      private

      override :build_preloads
      def build_preloads
        super + [:metadata, :job_definition_instance, :job_definition]
      end
    end
  end
end
