# frozen_string_literal: true

module EE
  module Projects
    module JobsController
      extend ActiveSupport::Concern

      prepended do
        before_action only: [:show] do
          push_frontend_ability(ability: :troubleshoot_job_with_ai, resource: @build, user: @current_user)
          set_application_context!
        end
      end

      def set_application_context!
        ::Gitlab::ApplicationContext.push(ai_resource: @build.try(:to_global_id)) # rubocop:disable Gitlab/ModuleWithInstanceVariables -- build comes from the main jobs controller
      end
    end
  end
end
