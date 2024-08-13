# frozen_string_literal: true

module EE
  module Projects
    module BoardsController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_force_frontend_feature_flag(:work_item_epics, project&.group&.work_item_epics_enabled?(current_user))
        end
      end
    end
  end
end
