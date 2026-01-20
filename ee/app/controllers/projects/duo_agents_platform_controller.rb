# frozen_string_literal: true

module Projects
  class DuoAgentsPlatformController < Projects::ApplicationController
    include DuoWorkflowConcern
    include AiDuoAgentPlatformFeatureFlags

    feature_category :duo_agent_platform
    before_action :check_access
    before_action do
      push_frontend_feature_flag(:ai_catalog_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_flow_trigger_pipeline_hooks, project.root_group)
      push_frontend_ability(ability: :read_ai_catalog_flow, resource: project, user: current_user)
      push_frontend_ability(ability: :read_ai_foundational_flow, resource: project, user: current_user)
      push_frontend_ability(ability: :read_ai_catalog_third_party_flow, resource: project, user: current_user)
      push_frontend_ability(ability: :create_ai_catalog_third_party_flow, resource: project, user: current_user)
    end

    def show; end

    private

    def check_access
      return render_404 unless Ability.allowed?(current_user, :duo_workflow, project)

      if specific_vueroute?
        render_404 unless authorized_for_route?
        return
      end

      render_404 unless duo_workflow_enabled?
    end

    def specific_vueroute?
      %w[agents flows triggers].include?(duo_agents_platform_params[:vueroute])
    end

    def authorized_for_route?
      case duo_agents_platform_params[:vueroute]
      when 'agents'
        Feature.enabled?(:global_ai_catalog, current_user)
      when 'triggers'
        current_user.can?(:manage_ai_flow_triggers, project)
      when 'flows'
        Feature.enabled?(:global_ai_catalog, current_user) &&
          (current_user.can?(:read_ai_catalog_flow, project) ||
           current_user.can?(:read_ai_foundational_flow, project))
      end
    end

    def duo_agents_platform_params
      params.permit(:vueroute)
    end
  end
end
