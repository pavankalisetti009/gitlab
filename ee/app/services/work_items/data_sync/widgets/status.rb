# frozen_string_literal: true

module WorkItems
  module DataSync
    module Widgets
      class Status < Base
        def before_create
          return unless target_work_item.get_widget(:status)
          return unless work_item.current_status

          target_work_item.build_current_status(
            work_item.current_status.slice(:system_defined_status_id, :custom_status_id)
          )
        end

        def post_move_cleanup
          work_item.current_status&.destroy!
        end
      end
    end
  end
end
