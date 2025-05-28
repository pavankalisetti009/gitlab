# frozen_string_literal: true

module EE
  module WorkItems
    module UpdateService
      extend ::Gitlab::Utils::Override
      include ::WorkItems::SyncAsEpic

      override :execute
      def execute(work_item)
        if params_include_state_and_status_changes?
          return error('State event and status widget cannot be changed at the same time', :bad_request)
        end

        super
      end

      private

      attr_reader :widget_params, :callbacks

      def transaction_update(work_item, opts = {})
        return super unless work_item.group_epic_work_item?

        super.tap do |save_result|
          break save_result unless save_result

          update_epic_for!(work_item)
        end
      end
    end
  end
end
