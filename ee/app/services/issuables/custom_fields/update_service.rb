# frozen_string_literal: true

module Issuables
  module CustomFields
    class UpdateService < BaseGroupService
      FeatureNotAvailableError = ServiceResponse.error(
        message: 'This feature is currently behind a feature flag and it is not available.'
      )
      NotAuthorizedError = ServiceResponse.error(
        message: "You don't have permissions to update a custom field for this group."
      )

      attr_reader :custom_field

      def initialize(custom_field:, **kwargs)
        super(group: custom_field.namespace, **kwargs)

        @custom_field = custom_field
      end

      def execute
        return FeatureNotAvailableError unless Feature.enabled?('custom_fields_feature', group)
        return NotAuthorizedError unless can?(current_user, :admin_custom_field, group)

        custom_field.assign_attributes(params.slice(:name))

        custom_field.updated_by = current_user if custom_field.changed?

        if custom_field.save
          ServiceResponse.success(payload: { custom_field: custom_field })
        else
          ServiceResponse.error(message: custom_field.errors.full_messages)
        end
      end
    end
  end
end
