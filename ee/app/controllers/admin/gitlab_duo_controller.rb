# frozen_string_literal: true

# EE:Self Managed
module Admin
  class GitlabDuoController < Admin::ApplicationController
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    respond_to :html

    feature_category :ai_abstraction_layer
    urgency :low

    before_action :ensure_feature_available!

    before_action do
      push_frontend_feature_flag(:ai_experiment_sast_fp_detection, current_user, type: :wip)
    end

    def show; end

    private

    def ensure_feature_available!
      render_404 unless License.current&.paid?
    end
  end
end
