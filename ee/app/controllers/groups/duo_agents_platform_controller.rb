# frozen_string_literal: true

module Groups
  class DuoAgentsPlatformController < Groups::ApplicationController
    feature_category :duo_agent_platform
    before_action :check_access
    before_action do
      push_frontend_feature_flag(:ai_catalog_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
    end

    def show; end

    private

    def check_access
      return render_404 unless Ability.allowed?(current_user, :duo_workflow, group)

      return unless specific_vueroute?

      render_404 unless authorized_for_route?
    end

    def specific_vueroute?
      %w[flows].include?(duo_agents_platform_params[:vueroute])
    end

    def authorized_for_route?
      case duo_agents_platform_params[:vueroute]
      when 'flows'
        Feature.enabled?(:global_ai_catalog, current_user) &&
          Feature.enabled?(:ai_catalog_flows, current_user)
      end
    end

    def duo_agents_platform_params
      params.permit(:vueroute)
    end
  end
end
