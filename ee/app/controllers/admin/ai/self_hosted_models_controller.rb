# frozen_string_literal: true

module Admin
  module Ai
    class SelfHostedModelsController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :"self-hosted_models"
      urgency :low

      before_action :ensure_registration!
      before_action :ensure_feature_enabled!

      def index; end

      private

      def ensure_registration!
        return if ::Ai::TestingTermsAcceptance.has_accepted?

        redirect_to admin_ai_terms_and_conditions_url
      end

      def ensure_feature_enabled!
        render_404 unless Ability.allowed?(current_user, :manage_ai_settings)
      end
    end
  end
end
