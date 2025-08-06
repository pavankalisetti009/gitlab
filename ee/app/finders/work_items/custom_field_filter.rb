# frozen_string_literal: true

module WorkItems
  class CustomFieldFilter < ::Issuables::BaseFilter
    def initialize(work_item_id_column: :id, **kwargs)
      @work_item_id_column = work_item_id_column

      super(**kwargs)
    end

    def filter(issuables)
      return issuables if params[:custom_field].blank?
      return issuables if parent && !parent.licensed_feature_available?(:custom_fields)

      params[:custom_field].inject(issuables) do |issuables, filter_params|
        custom_field = if filter_params[:custom_field_id]
                         Issuables::CustomField.find_by_id(filter_params[:custom_field_id])
                       elsif @parent
                         Issuables::CustomField.of_namespace(@parent.root_ancestor)
                                        .find_by_case_insensitive_name(
                                          filter_params[:custom_field_name]
                                        )
                       end

        next issuables.none if custom_field.nil?

        filter_by_field_type(issuables, custom_field, filter_params)
      end
    end

    private

    def filter_by_field_type(issuables, custom_field, filter_params)
      return issuables.none unless custom_field.field_type_select?

      filter_select_field(issuables, custom_field, filter_params)
    end

    def filter_select_field(issuables, custom_field, filter_params)
      select_option_ids = filter_params[:selected_option_ids] ||
        Issuables::CustomFieldSelectOption.of_field(custom_field)
          .with_case_insensitive_values(filter_params[:selected_option_values]).pluck_primary_key

      if filter_params[:selected_option_ids].nil? &&
          select_option_ids.size != filter_params[:selected_option_values].size
        return issuables.none
      end

      # rubocop: disable CodeReuse/ActiveRecord -- Used only for this filter
      select_option_ids.inject(issuables) do |issuables, select_option_id|
        issuables.where_exists(
          WorkItems::SelectFieldValue.where(
            custom_field_id: custom_field.id,
            custom_field_select_option_id: select_option_id
          ).where(
            WorkItems::SelectFieldValue.arel_table[:work_item_id].eq(issuables.arel_table[@work_item_id_column])
          )
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
