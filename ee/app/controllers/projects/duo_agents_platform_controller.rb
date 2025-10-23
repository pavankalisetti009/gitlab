# frozen_string_literal: true

module Projects
  class DuoAgentsPlatformController < Projects::ApplicationController
    feature_category :duo_agent_platform
    before_action :check_access
    before_action do
      push_frontend_feature_flag(:ai_catalog_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_item_project_curation, current_user)
    end

    def show; end

    private

    def check_access
      return render_404 unless Ability.allowed?(current_user, :duo_workflow, project)

      if specific_vueroute?
        render_404 unless authorized_for_route?
        return
      end

      return render_404 unless project&.duo_remote_flows_enabled

      render_404 unless ::Feature.enabled?(:duo_workflow_in_ci, current_user) && ::Ai::DuoWorkflow.enabled?
    end

    def specific_vueroute?
      %w[agents flows flow-triggers].include?(duo_agents_platform_params[:vueroute])
    end

    def authorized_for_route?
      case duo_agents_platform_params[:vueroute]
      when 'agents'
        Feature.enabled?(:global_ai_catalog, current_user)
      when 'flow-triggers'
        current_user.can?(:manage_ai_flow_triggers, project)
      when 'flows'
        Feature.enabled?(:global_ai_catalog, current_user) &&
          (Feature.enabled?(:ai_catalog_flows, current_user) ||
                Feature.enabled?(:ai_catalog_third_party_flows, current_user))
      end
    end

    def duo_agents_platform_params
      params.permit(:vueroute)
    end
  end
end
