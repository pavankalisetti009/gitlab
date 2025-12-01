# frozen_string_literal: true

module EE
  module Groups
    module BoardsController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_force_frontend_feature_flag(:work_item_epics, group.allowed_work_item_type?(:epic))
        end
      end
    end
  end
end
