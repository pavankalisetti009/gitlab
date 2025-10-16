# frozen_string_literal: true

module Ai
  module ModelSelection
    class FetchModelDefinitionsService
      include ::Gitlab::Llm::Concerns::Logger

      DEFAULT_TIMEOUT = 5.seconds
      RESPONSE_CACHE_EXPIRATION = 30.minutes
      RESPONSE_CACHE_NAME = 'ai_offered_model_definitions'

      def initialize(user, model_selection_scope:)
        @user = user
        @model_selection_scope = model_selection_scope
      end

      def execute
        return ServiceResponse.success(payload: nil) unless duo_features_enabled?
        return ServiceResponse.success(payload: nil) if ::License.current&.offline_cloud_license?

        return cached_response if use_cached_response?

        fetch_model_definitions
      rescue StandardError => e
        Gitlab::AppLogger.error(
          message: "Error fetching model definitions: #{e.message}",
          exception: e.class.name,
          ai_component: 'model_selection'
        )
        ServiceResponse.error(message: "Failed to fetch model definitions")
      end

      private

      attr_reader :user, :model_selection_scope

      def duo_features_enabled?
        return false unless ::Gitlab::CurrentSettings.current_application_settings.duo_features_enabled

        true
      end

      def fetch_model_definitions
        response = call_endpoint

        if response.success?
          cache_response(response.parsed_response)
          ServiceResponse.success(payload: response.parsed_response)
        else
          parsed_response = response.parsed_response
          error_message = "Received error #{response.code} from AI gateway when fetching model definitions"

          log_error(message: error_message,
            event_name: 'error_response_received',
            ai_component: 'abstraction_layer',
            response_from_llm: parsed_response)

          ServiceResponse.error(message: error_message)
        end
      end

      def call_endpoint
        Gitlab::HTTP.get(
          endpoint,
          headers: Gitlab::AiGateway.headers(
            user: user, unit_primitive_name: :code_suggestions, ai_feature_name: :code_suggestions
          ),
          timeout: DEFAULT_TIMEOUT,
          allow_local_requests: true
        )
      end

      def cache_response(response_body)
        Rails.cache.fetch(RESPONSE_CACHE_NAME, expires_in: RESPONSE_CACHE_EXPIRATION) do
          response_body
        end
      end

      def cached_response
        cached_model_definitions = Rails.cache.fetch(RESPONSE_CACHE_NAME)
        ServiceResponse.success(payload: cached_model_definitions)
      end

      def endpoint
        # GitLab Model selection data should always come from cloud connected, never from local AIGW
        base_url = if local_development?
                     Gitlab::AiGateway.url
                   else
                     Gitlab::AiGateway.cloud_connector_url
                   end

        endpoint_route = 'models%2Fdefinitions'

        "#{base_url}/v1/#{endpoint_route}"
      end

      def local_development?
        ::Gitlab::Utils.to_boolean(ENV['FETCH_MODEL_SELECTION_DATA_FROM_LOCAL'], default: false)
      end

      def use_cached_response?
        Rails.cache.exist?(RESPONSE_CACHE_NAME) && !local_development?
      end
    end
  end
end
