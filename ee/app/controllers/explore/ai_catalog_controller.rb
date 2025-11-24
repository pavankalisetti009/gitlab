# frozen_string_literal: true

module Explore
  class AiCatalogController < Explore::ApplicationController
    feature_category :workflow_catalog
    # The Ai::Catalog.available? check for SaaS requires an authenticated user.
    # TODO remove `before_action :authenticate_user!` when AI Catalog goes GA.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/570161
    before_action :authenticate_user!
    before_action :authorize_read_ai_catalog!
    before_action do
      push_frontend_feature_flag(:ai_catalog_agents, current_user)
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_flows, current_user)
    end

    private

    def authorize_read_ai_catalog!
      render_404 unless can?(current_user, :read_ai_catalog)
    end
  end
end
