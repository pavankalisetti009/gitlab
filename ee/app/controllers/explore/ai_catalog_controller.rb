# frozen_string_literal: true

module Explore
  class AiCatalogController < Explore::ApplicationController
    feature_category :workflow_catalog
    before_action :check_feature_flag
    before_action do
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_flows, current_user)
    end

    private

    def check_feature_flag
      render_404 unless Feature.enabled?(:global_ai_catalog, current_user)
    end
  end
end
