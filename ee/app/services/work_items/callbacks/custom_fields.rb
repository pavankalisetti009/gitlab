# frozen_string_literal: true

module WorkItems
  module Callbacks
    class CustomFields < Base
      include Gitlab::InternalEventsTracking

      # `params` for this widget callback is in the format:
      # [
      #   { custom_field_id: 1, text_value: 'text' },
      #   { custom_field_id: 2, number_value: 100 },
      #   { custom_field_id: 3, selected_option_ids: [1, 2, 3] }
      # ]
      # Only values for the provided custom_field_ids are mutated. Omitted ones are left as-is.
      def after_save
        return unless Feature.enabled?(:custom_fields_feature, work_item.namespace.root_ancestor)
        return unless has_permission?(:set_work_item_metadata)

        custom_fields = ::Issuables::CustomFieldsFinder.active_fields_for_work_item(work_item)
                          .id_in(params.pluck(:custom_field_id)) # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- params is an Array
                          .index_by(&:id)

        params.each do |field_params|
          custom_field = custom_fields[field_params[:custom_field_id].to_i]

          raise_error "Invalid custom field ID: #{field_params[:custom_field_id]}" if custom_field.nil?

          update_work_item_field_value(custom_field, field_params)
        end

        track_internal_event(
          'change_work_item_custom_field_value',
          namespace: work_item.project&.namespace || work_item.namespace,
          project: work_item.project,
          user: current_user
        )
      end

      private

      def update_work_item_field_value(custom_field, field_params)
        if custom_field.field_type_text?
          WorkItems::TextFieldValue
            .update_work_item_field!(work_item, custom_field, field_params[:text_value])
        elsif custom_field.field_type_number?
          WorkItems::NumberFieldValue
            .update_work_item_field!(work_item, custom_field, field_params[:number_value])
        elsif custom_field.field_type_select?
          WorkItems::SelectFieldValue
            .update_work_item_field!(work_item, custom_field, field_params[:selected_option_ids])
        else
          raise_error "Unsupported field type: #{custom_field.field_type}"
        end
      rescue ActiveRecord::RecordInvalid, ArgumentError => e
        raise_error e.message
      end
    end
  end
end
