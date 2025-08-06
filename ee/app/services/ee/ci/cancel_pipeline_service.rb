# frozen_string_literal: true

module EE
  module Ci
    module CancelPipelineService
      extend ::Gitlab::Utils::Override

      private

      override :build_preloads
      def build_preloads
        super + [:metadata]
      end
    end
  end
end
