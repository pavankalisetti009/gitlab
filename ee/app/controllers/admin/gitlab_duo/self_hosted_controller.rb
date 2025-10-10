# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class SelfHostedController < Admin::ApplicationController
      feature_category :"self-hosted_models"
      urgency :low

      before_action :authorize_feature!

      def index; end

      private

      def authorize_feature!
        return if can_any?(current_user, %i[manage_self_hosted_models_settings manage_instance_model_selection])

        render_404
      end
    end
  end
end
