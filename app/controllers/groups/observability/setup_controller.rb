# frozen_string_literal: true

module Groups
  module Observability
    class SetupController < Groups::ApplicationController
      before_action :authenticate_user!
      before_action :authorize_request_access!

      feature_category :observability
      urgency :low

      def show
        @settings = group.observability_group_o11y_setting
        return unless provisioning?

        @configuration_settings ||= group.build_observability_group_o11y_setting(o11y_service_name: group.id)
      end

      private

      def authorize_request_access!
        return render_404 unless ::Feature.enabled?(:observability_sass_features, group)

        return if Ability.allowed?(current_user, :create_observability_access_request, group)

        render_403
      end

      def provisioning?
        params.permit(:provisioning)[:provisioning] == 'true'
      end
    end
  end
end
