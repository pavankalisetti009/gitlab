# frozen_string_literal: true

module Issuables
  module CustomFields
    class CreateService < BaseGroupService
      FeatureNotAvailableError = ServiceResponse.error(
        message: 'This feature is currently behind a feature flag and it is not available.'
      )
      NotAuthorizedError = ServiceResponse.error(
        message: "You don't have permissions to create a custom field for this group."
      )

      def execute
        return FeatureNotAvailableError unless Feature.enabled?('custom_fields_feature', group)
        return NotAuthorizedError unless can?(current_user, :admin_custom_field, group)

        custom_field = Issuables::CustomField.new(
          namespace: group,
          created_by: current_user
        )

        custom_field.assign_attributes(params.slice(:field_type, :name))

        if custom_field.save
          ServiceResponse.success(payload: { custom_field: custom_field })
        else
          ServiceResponse.error(message: custom_field.errors.full_messages)
        end
      end
    end
  end
end
