# frozen_string_literal: true

module WorkItems
  module Lifecycles
    class CreateService < BaseService
      include Gitlab::InternalEventsTracking

      def initialize(container:, current_user: nil, params: {})
        super
      end

      def execute
        return FeatureNotAvailableError unless feature_flag_enabled?

        result = create_custom_lifecycle!

        track_internal_events_for_statuses

        ServiceResponse.success(payload: { lifecycle: result })
      rescue StandardError => e
        ServiceResponse.error(message: e.message)
      end

      private

      def create_custom_lifecycle!
        ApplicationRecord.transaction do
          ensure_custom_lifecycle_and_status!

          apply_status_changes(params[:statuses])

          statuses = @processed_statuses
          default_statuses = default_statuses_for_lifecycle(statuses, params)

          ::WorkItems::Statuses::Custom::Lifecycle.create!(
            namespace: group,
            name: params[:name],
            statuses: statuses,
            default_open_status: default_statuses[:default_open_status],
            default_closed_status: default_statuses[:default_closed_status],
            default_duplicate_status: default_statuses[:default_duplicate_status],
            created_by: current_user
          )
        end
      end

      def feature_flag_enabled?
        group.try(:work_item_status_mvc2_feature_flag_enabled?)
      end
    end
  end
end
