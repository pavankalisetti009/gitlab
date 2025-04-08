# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    class CreateService
      MAPPED_WIDGET_PARAMS = {
        description_widget: [:description],
        labels_widget: [:label_ids, :add_label_ids, :remove_label_ids],
        hierarchy_widget: [:parent_id, :parent],
        start_and_due_date_widget: [
          :end_date, :due_date, :due_date_fixed, :due_date_is_fixed, :start_date, :start_date_fixed,
          :start_date_is_fixed
        ],
        color_widget: [:color]
      }.freeze

      WORK_ITEM_NOT_FOUND_ERROR = 'No matching work item found'
      EPIC_NOT_FOUND_ERROR = 'No matching epic found. Make sure that you are adding a valid epic URL.'

      def initialize(group:, perform_spam_check: true, current_user: nil, params: {})
        @group = group
        @current_user = current_user
        # Convert to Hash because params may be an instance of ActionController::Params
        @params = params.to_hash.symbolize_keys!
        @perform_spam_check = perform_spam_check
      end

      def execute_without_rate_limiting
        execute(without_rate_limiting: true)
      end

      def execute(without_rate_limiting: false)
        execute_method = without_rate_limiting ? :execute_without_rate_limiting : :execute
        service_result = create_service.try(execute_method)

        transform_result(service_result)
      end

      private

      def create_service
        epic_work_item_type = ::WorkItems::Type.default_by_type(:epic)
        transformed_params, widget_params = extract_widget_params(epic_work_item_type)

        ::WorkItems::CreateService.new(
          container: group,
          perform_spam_check: perform_spam_check,
          current_user: current_user,
          params: transformed_params,
          widget_params: widget_params
        )
      end

      def extract_widget_params(work_item_type)
        widget_params = {}

        MAPPED_WIDGET_PARAMS.each do |widget_name, widget_param_keys|
          params_for_widget = params.extract!(*widget_param_keys)

          next if params_for_widget.empty?

          widget_params[widget_name] = case widget_name
                                       when :labels_widget
                                         labels_params(params_for_widget)
                                       when :hierarchy_widget
                                         hierarchy_params(params_for_widget)
                                       when :start_and_due_date_widget
                                         dates_params(params_for_widget)
                                       else
                                         params_for_widget
                                       end
        end

        params[:work_item_type] = work_item_type

        [params, widget_params]
      end

      def labels_params(epic_params)
        {
          add_label_ids: epic_params.values_at(:label_ids, :add_label_ids).flatten.compact,
          remove_label_ids: epic_params[:remove_label_ids]
        }
      end

      def hierarchy_params(epic_params)
        parent_work_item = Epic.find_by_id(epic_params[:parent_id] || epic_params[:parent])&.work_item

        return unless parent_work_item

        { parent: parent_work_item }
      end

      def dates_params(epic_params)
        work_item_date_params = {}

        work_item_date_params[:is_fixed] = epic_params[:due_date_is_fixed] || epic_params[:start_date_is_fixed]

        if epic_params.key?(:due_date_fixed)
          work_item_date_params[:due_date] = epic_params[:due_date_fixed]
        elsif epic_params.key?(:end_date)
          work_item_date_params[:due_date] = epic_params[:end_date]
        end

        if epic_params.key?(:start_date_fixed)
          work_item_date_params[:start_date] = epic_params[:start_date_fixed]
        elsif epic_params.key?(:start_date)
          work_item_date_params[:start_date] = epic_params[:start_date]
        end

        work_item_date_params
      end

      def transform_result(result)
        # The legacy service Epics::CreateService returns an epic record instead of a service response
        # so in case of failing to create the work item we create a new epic that includes the service errors
        new_epic = result.payload[:work_item]&.reload&.synced_epic || Epic.new

        if result.try(:error?)
          new_epic.errors.add(:base,
            result[:message].include?(WORK_ITEM_NOT_FOUND_ERROR) ? EPIC_NOT_FOUND_ERROR : result[:message])
        end

        new_epic
      end

      attr_reader :group, :current_user, :params, :perform_spam_check
    end
  end
end
