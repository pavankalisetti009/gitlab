# frozen_string_literal: true

module EE
  module Groups
    module BoardsController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_force_frontend_feature_flag(:work_item_epics, group.work_item_epics_enabled?)
          push_frontend_feature_flag(:namespace_level_work_items, group)
        end
      end
    end
  end
end
