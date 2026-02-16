# frozen_string_literal: true

module WorkItems
  module Types
    class UpdateService < BaseContainerService
      FeatureNotAvailableError = ServiceResponse.error(
        message: 'Feature not available'
      )

      InvalidContainerError = ServiceResponse.error(
        message: 'Work item types can only be updated at the root group or organization level'
      )

      WorkItemTypeNotFoundError = ServiceResponse.error(
        message: 'Work item type not found'
      )

      def initialize(container:, current_user: nil, params: {})
        super
      end

      def execute
        return FeatureNotAvailableError unless feature_available?
        return InvalidContainerError unless valid_container?

        work_item_type = find_work_item_type
        return WorkItemTypeNotFoundError unless work_item_type

        ServiceResponse.success(payload: {
          work_item_type: work_item_type,
          resource_parent: resolved_container
        })
      end

      private

      def resolved_container
        container.respond_to?(:sync) ? container.sync : container
      end
      strong_memoize_attr :resolved_container

      def work_item_type_provider
        ::WorkItems::TypesFramework::Provider.new(resolved_container)
      end
      strong_memoize_attr :work_item_type_provider

      def feature_available?
        Feature.enabled?(:work_item_configurable_types, :instance)
      end

      def valid_container?
        return true if resolved_container.is_a?(::Organizations::Organization)
        return true if resolved_container.is_a?(::Group) && resolved_container.root?

        false
      end

      def find_work_item_type
        return unless params[:id]

        work_item_type_provider.find_by_id(GlobalID.parse(params[:id])&.model_id)
      end
    end
  end
end
