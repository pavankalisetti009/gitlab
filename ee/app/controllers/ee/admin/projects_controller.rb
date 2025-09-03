# frozen_string_literal: true

module EE
  module Admin
    module ProjectsController
      extend ActiveSupport::Concern

      prepended do
        authorize! :read_admin_projects, only: %i[index show]

        before_action :limited_actions_message!, only: :show

        before_action only: :index do
          push_frontend_feature_flag(:custom_ability_read_admin_projects, current_user)
        end
      end
    end
  end
end
