# frozen_string_literal: true

module Projects
  class DuoAgentsPlatformController < Projects::ApplicationController
    feature_category :duo_workflow
    before_action :check_access

    def show; end

    private

    def check_access
      if duo_agents_platform_params[:vueroute] == 'flow-triggers'
        render_404 unless current_user.can?(:manage_ai_flow_triggers, project)
        return
      end

      render_404 unless ::Feature.enabled?(:duo_workflow_in_ci, current_user) && ::Ai::DuoWorkflow.enabled?
    end

    def duo_agents_platform_params
      params.permit(:vueroute)
    end
  end
end
