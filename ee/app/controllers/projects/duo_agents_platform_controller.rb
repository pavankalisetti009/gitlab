# frozen_string_literal: true

module Projects
  class DuoAgentsPlatformController < Projects::ApplicationController
    feature_category :agent_foundations
    before_action :check_access

    def show; end

    private

    def check_access
      return render_404 unless project&.duo_features_enabled

      if duo_agents_platform_params[:vueroute] == 'flow-triggers'
        render_404 unless current_user.can?(:manage_ai_flow_triggers, project)
        return
      end

      if duo_agents_platform_params[:vueroute] == 'flows'
        render_404 unless Feature.enabled?(:global_ai_catalog, current_user)
        return
      end

      return render_404 unless project&.duo_remote_flows_enabled

      render_404 unless ::Feature.enabled?(:duo_workflow_in_ci, current_user) && ::Ai::DuoWorkflow.enabled?
    end

    def duo_agents_platform_params
      params.permit(:vueroute)
    end
  end
end
