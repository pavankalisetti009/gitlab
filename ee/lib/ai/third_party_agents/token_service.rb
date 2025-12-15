# frozen_string_literal: true

module Ai
  module ThirdPartyAgents
    class TokenService
      include Gitlab::Llm::Concerns::Logger

      DEFAULT_TIMEOUT = 30.seconds

      DirectAccessError = Class.new(StandardError)

      def initialize(current_user:, project: nil)
        @current_user = current_user
        @project = project
      end

      def direct_access_token
        log_info(message: 'Creating user access token',
          event_name: 'user_token_created',
          ai_component: 'third_party_agents'
        )

        response = Gitlab::HTTP.post(
          Gitlab::AiGateway.access_token_url(nil),
          headers: ai_gateway_headers,
          body: nil,
          timeout: DEFAULT_TIMEOUT,
          allow_local_requests: true,
          stream_body: false
        )

        return error_response('Token creation failed', response) unless response.success?
        return error_response('Token is missing in response', response) unless response['token'].present?

        ServiceResponse.success(
          message: "Direct Access Token Generated",
          payload: {
            headers: public_headers,
            token: response['token'],
            expires_at: response['expires_at']
          }
        )
      end

      private

      attr_reader :current_user, :project

      def ai_gateway_headers
        Gitlab::AiGateway.headers(
          user: current_user,
          unit_primitive_name: :ai_gateway_model_provider_proxy,
          namespace_id: project&.namespace_id,
          root_namespace_id: project&.root_namespace&.id,
          ai_feature_name: :duo_workflow
        ).merge(project_headers)
      end

      def public_headers
        Gitlab::AiGateway.public_headers(
          user: current_user,
          ai_feature_name: :duo_workflow,
          unit_primitive_name: :ai_gateway_model_provider_proxy,
          namespace_id: project&.namespace_id,
          root_namespace_id: project&.root_namespace&.id
        ).merge(
          'x-gitlab-unit-primitive' => 'ai_gateway_model_provider_proxy',
          'x-gitlab-authentication-type' => 'oidc',
          **project_headers
        )
      end

      def project_headers
        return {} unless project

        { 'x-gitlab-project-id' => project.id.to_s }
      end

      def error_response(message, response)
        error_context = {}.tap do |h|
          next if response.nil?

          h[:ai_gateway_response_code] = response.code
          if response.parsed_response.is_a?(String)
            h[:ai_gateway_error_detail] = response.parsed_response
          elsif response.respond_to?(:dig) && response.parsed_response&.dig("detail")
            h[:ai_gateway_error_detail] = response.parsed_response["detail"]
          end
        end

        Gitlab::ErrorTracking.track_exception(DirectAccessError.new(message), error_context)

        ServiceResponse.error(message: message)
      end
    end
  end
end
