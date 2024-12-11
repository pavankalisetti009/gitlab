# frozen_string_literal: true

module Admin
  module Ai
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
          identityProviderPayload: identity_provider,
          amazonQSettings: {
            ready: ::Ai::Setting.instance.amazon_q_ready,
            roleArn: ::Ai::Setting.instance.amazon_q_role_arn,
            availability: Gitlab::CurrentSettings.duo_availability
          }
        }
      end

      def identity_provider
        return if ::Ai::Setting.instance.amazon_q_ready

        result = ::Ai::AmazonQ::IdentityProviderPayloadFactory.new.execute
        case result
        in { ok: payload }
          payload
        in { err: err }
          flash[:alert] = [
            s_('AmazonQ|Something went wrong retrieving the identity provider payload.'),
            err[:message]
          ].reject(&:blank?).join(' ')

          {}
        end
      end

      def check_can_admin_amazon_q
        render_404 unless ::Ai::AmazonQ.feature_available?
      end
    end
  end
end
