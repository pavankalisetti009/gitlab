# frozen_string_literal: true

module EE
  module WorkItems
    module SavedViews
      module FilterSanitizerService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          result = super
          return result unless result.success?

          validate_custom_fields

          validate_iteration
          validate_negated_iteration
          validate_iteration_cadence_id

          validate_status

          ServiceResponse.success(payload: { filters: sanitized_filters, warnings: warnings })
        rescue ArgumentError => e
          ServiceResponse.error(message: e.message)
        end

        private

        def validate_custom_fields
          validate_custom_field_filter(:custom_field, :custom_field)
          validate_custom_field_filter([:not, :custom_field], :not_custom_field)
          validate_custom_field_filter([:or, :custom_field], :or_custom_field)
        end

        def validate_custom_field_filter(filter_path, warning_key)
          filter_value = filter_path.is_a?(Array) ? filters.dig(*filter_path) : filters[filter_path]
          return unless filter_value

          output_location = initialize_custom_field_output(filter_path)

          filter_value.each do |cf|
            custom_field_id = cf[:custom_field_id].to_i
            selected_option_ids = cf[:selected_option_ids].map(&:to_i)

            result = validate_custom_field_options(custom_field_id, selected_option_ids, warning_key)
            next if result[:valid_options].empty? || result[:custom_field].nil?

            output_location[:custom_field] << {
              custom_field_id: result[:custom_field].to_gid.to_s,
              selected_option_ids: result[:valid_options].map { |option| option.to_gid.to_s }
            }
          end
        end

        def initialize_custom_field_output(filter_path)
          if filter_path.is_a?(Array)
            context_key = filter_path.first
            sanitized_filters[context_key] ||= {}
            output_location = sanitized_filters[context_key]
          else
            output_location = sanitized_filters
          end

          output_location[:custom_field] = []
          output_location
        end

        def validate_custom_field_options(custom_field_id, selected_option_ids, warning_key)
          custom_field = ::Issuables::CustomField.find_by_id(custom_field_id)

          unless custom_field
            add_warning(warning_key, "Custom field #{custom_field_id} not found")
            return { valid_options: [], custom_field: nil }
          end

          valid_options = ::Issuables::CustomFieldSelectOption
            .of_field(custom_field_id)
            .id_in(selected_option_ids)

          missing_count = selected_option_ids.size - valid_options.size
          if missing_count > 0
            add_warning(warning_key, "#{missing_count} option(s) not found for custom field #{custom_field_id}")
          end

          { valid_options: valid_options, custom_field: custom_field }
        end

        def validate_iteration
          return unless filters[:iteration_id]

          found_ids = ::Iteration.id_in(filters[:iteration_id]).map { |i| i.id.to_s }
          add_missing_warning(:iteration_id, filters[:iteration_id].size, found_ids.size, 'iteration(s)')

          sanitized_filters[:iteration_id] = found_ids if found_ids.any?
        end

        def validate_negated_iteration
          return unless filters.dig(:not, :iteration_id)

          found_ids = ::Iteration.id_in(filters[:not][:iteration_id]).map { |i| i.id.to_s }
          add_missing_warning(:not_iteration_id, filters[:not][:iteration_id].size, found_ids.size, 'iteration(s)')

          return unless found_ids.any?

          sanitized_filters[:not] ||= {}
          sanitized_filters[:not][:iteration_id] = found_ids
        end

        def validate_iteration_cadence_id
          return unless filters[:iteration_cadence_ids]

          found_cadences = ::Iterations::Cadence.id_in(filters[:iteration_cadence_ids])
          found_ids = found_cadences.map { |c| c.to_gid.to_s }

          add_missing_warning(:iteration_cadence_id, filters[:iteration_cadence_ids].size, found_cadences.size,
            'iteration cadence(s)')

          sanitized_filters[:iteration_cadence_id] = found_ids if found_ids.any?
        end

        def validate_status
          return unless filters[:status]

          status_data = filters[:status]
          return unless status_data.is_a?(Hash)

          status_id = status_data[:id] || status_data['id']
          return unless status_id

          status = find_custom_status(status_id) || find_system_defined_status(status_id)

          return add_warning(:status, "Status not found") unless status

          sanitized_filters[:status] = { name: status.name }
        end

        def find_custom_status(status_id)
          ::WorkItems::Statuses::Finder.new(
            container.root_ancestor,
            { 'custom_status_id' => status_id },
            current_user
          ).find_single_status
        end

        def find_system_defined_status(status_id)
          ::WorkItems::Statuses::Finder.new(
            nil,
            { 'system_defined_status_identifier' => status_id },
            current_user
          ).find_single_status
        end
      end
    end
  end
end
