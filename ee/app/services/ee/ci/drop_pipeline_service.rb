# frozen_string_literal: true

module EE
  module Ci
    module DropPipelineService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :preloaded_relations
      def preloaded_relations
        super + [:security_report_artifacts]
      end
    end
  end
end
