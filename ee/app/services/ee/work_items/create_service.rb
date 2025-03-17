# frozen_string_literal: true

module EE
  module WorkItems
    module CreateService
      extend ::Gitlab::Utils::Override
      include ::WorkItems::SyncAsEpic

      private

      attr_reader :widget_params, :callbacks

      override :run_after_create_callbacks
      def run_after_create_callbacks(work_item)
        create_epic_for!(work_item) if work_item.group_epic_work_item?
        super
      end
    end
  end
end
