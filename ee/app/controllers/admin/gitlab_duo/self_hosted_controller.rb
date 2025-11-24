# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class SelfHostedController < Admin::ApplicationController
      feature_category :"self-hosted_models"
      urgency :low

      before_action :authorize_feature!
      before_action :authorize_model_management!

      def index; end

      private

      def authorize_feature!
        return if can_any?(current_user, %i[manage_self_hosted_models_settings manage_instance_model_selection])

        render_404
      end

      def authorize_model_management!
        vueroute = params.permit(:vueroute)[:vueroute]
        return unless vueroute&.start_with?('models/new') || vueroute&.match?(%r{\Amodels/\d+/edit\z})
        return if can?(current_user, :manage_self_hosted_models_settings)

        render_404
      end
    end
  end
end
