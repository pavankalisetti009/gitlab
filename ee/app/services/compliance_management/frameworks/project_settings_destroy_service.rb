# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    class ProjectSettingsDestroyService < BaseService
      def initialize(framework_ids:)
        @framework_ids = Array(framework_ids)
      end

      def execute
        deleted_count = ComplianceManagement::ComplianceFramework::ProjectSettings.delete_by_framework(framework_ids)

        ServiceResponse.success(
          message: "Destroyed related project settings for frameworks",
          payload: { deleted_count: deleted_count }
        )
      rescue StandardError => e
        ServiceResponse.error(
          message: "Failed to delete project settings for frameworks: #{e.message}"
        )
      end

      private

      attr_reader :framework_ids
    end
  end
end
