# frozen_string_literal: true

module WorkItems
  module Lifecycles
    class UpdateService < BaseService
      FeatureNotAvailableError = ServiceResponse.error(
        message: 'This feature is currently behind a feature flag, and it is not available.'
      )

      NotAuthorizedError = ServiceResponse.error(
        message: "You don't have permission to update a lifecycle for this namespace."
      )

      InvalidLifecycleTypeError = ServiceResponse.error(
        message: 'Invalid lifecycle type. Custom lifecycle already exists.'
      )

      def initialize(container:, current_user: nil, params: {})
        super
      end

      def execute
        return FeatureNotAvailableError unless feature_available?
        return NotAuthorizedError unless authorized?
        return InvalidLifecycleTypeError if invalid_lifecycle_type?

        result = custom_lifecycle_present? ? update_custom_lifecycle! : create_custom_lifecycle!

        ServiceResponse.success(payload: { lifecycle: result })
      rescue StandardError => e
        ServiceResponse.error(message: e.message)
      end

      private

      def update_custom_lifecycle!
        ApplicationRecord.transaction do
          apply_status_changes

          if @processed_statuses.present?
            validate_status_removal_constraints
            update_lifecycle_status_positions!
            lifecycle.assign_attributes(default_statuses_for_lifecycle(@processed_statuses, params))
            lifecycle.validate!
          end

          lifecycle.updated_by = current_user if lifecycle.changed?
          lifecycle.save! if lifecycle.changed?

          handle_deferred_status_removal
          lifecycle
        end
      end

      def create_custom_lifecycle!
        ApplicationRecord.transaction do
          apply_status_changes

          validate_status_removal_constraints

          statuses = @processed_statuses
          default_statuses = default_statuses_for_lifecycle(statuses, params)

          ::WorkItems::Statuses::Custom::Lifecycle.create!(
            namespace: group,
            name: lifecycle.name,
            work_item_types: lifecycle.work_item_types,
            statuses: statuses,
            default_open_status: default_statuses[:default_open_status],
            default_closed_status: default_statuses[:default_closed_status],
            default_duplicate_status: default_statuses[:default_duplicate_status],
            created_by: current_user
          )
        end
      end

      def invalid_lifecycle_type?
        system_defined_lifecycle? && group.custom_lifecycles.exists?(name: lifecycle.name) # rubocop:disable CodeReuse/ActiveRecord -- skip
      end

      def custom_lifecycle_present?
        custom_lifecycle? && group.custom_lifecycles.exists?(id: lifecycle.id) # rubocop:disable CodeReuse/ActiveRecord -- skip
      end

      def lifecycle
        id_param = params[:id]
        global_id = GlobalID.parse(id_param)
        global_id.model_class.find(global_id.model_id.to_i)
      end
      strong_memoize_attr :lifecycle
    end
  end
end
