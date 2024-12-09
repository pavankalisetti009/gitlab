# frozen_string_literal: true

module Admin
  module Ai
    # NOTE: This module is under development. See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/174614
    class AmazonQSettingsController < Admin::ApplicationController
      feature_category :ai_abstraction_layer

      before_action :check_can_admin_amazon_q

      def index
        setup_view_model
      end

      private

      def setup_view_model
        @view_model = {
          submitUrl: admin_ai_amazon_q_settings_path,
          amazonQSettings: {
            ready: ::Ai::Setting.instance.amazon_q_ready,
            roleArn: ::Ai::Setting.instance.amazon_q_role_arn,
            availability: Gitlab::CurrentSettings.duo_availability
          }
        }
      end

      def check_can_admin_amazon_q
        render_404 unless ::Ai::AmazonQ.feature_available?
      end
    end
  end
end
