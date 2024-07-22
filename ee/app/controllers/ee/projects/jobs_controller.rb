# frozen_string_literal: true

module EE
  module Projects
    module JobsController
      extend ActiveSupport::Concern

      prepended do
        before_action only: [:show] do
          push_frontend_ability(ability: :troubleshoot_job_with_ai, resource: @build, user: @current_user)
          push_frontend_feature_flag(:root_cause_analysis_duo, @current_user)
        end
      end
    end
  end
end
