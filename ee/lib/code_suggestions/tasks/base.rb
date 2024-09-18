# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class Base
      AI_GATEWAY_CONTENT_SIZE = 100_000

      def initialize(params: {}, unsafe_passthrough_params: {}, current_user: nil)
        @feature_setting = ::Ai::FeatureSetting.find_by_feature(feature_setting_name)
        @params = params
        @unsafe_passthrough_params = unsafe_passthrough_params
        @current_user = current_user
      end

      def base_url
        feature_setting&.base_url || Gitlab::AiGateway.url
      end

      def self_hosted?
        feature_setting&.self_hosted?
      end

      def feature_name
        if self_hosted?
          :self_hosted_models
        else
          :code_suggestions
        end
      end

      def endpoint
        "#{base_url}/v2/code/#{endpoint_name}"
      end

      def body
        body_params = unsafe_passthrough_params.merge(prompt.request_params)

        trim_content_params(body_params)

        body_params.to_json
      end

      private

      attr_reader :params, :unsafe_passthrough_params, :feature_setting, :current_user

      def endpoint_name
        raise NotImplementedError
      end

      # override this method in Tasks::Completion/Generation classes
      def feature_setting_name
        raise NotImplementedError
      end

      def trim_content_params(body_params)
        return unless body_params[:current_file]

        body_params[:current_file][:content_above_cursor] =
          body_params[:current_file][:content_above_cursor].to_s.last(AI_GATEWAY_CONTENT_SIZE)
        body_params[:current_file][:content_below_cursor] =
          body_params[:current_file][:content_below_cursor].to_s.first(AI_GATEWAY_CONTENT_SIZE)
      end
    end
  end
end
