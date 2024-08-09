# frozen_string_literal: true

module CloudConnector
  class AvailableServices
    class << self
      def find_by_name(name)
        service_data_map = available_services
        return CloudConnector::MissingServiceData.new if service_data_map.empty? || !service_data_map[name].present?

        service_data_map[name]
      end

      def available_services
        access_data_reader.read_available_services
      end

      def access_data_reader
        if use_self_signed_token?
          SelfSigned::AccessDataReader.new
        else
          SelfManaged::AccessDataReader.new
        end
      end

      private

      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- we don't have dedicated SM/.com Cloud Connector features
      # or other checks that would allow us to identify where the code is running. We rely on instance checks for now.
      # Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
      def use_self_signed_token?
        return true if Gitlab.org_or_com?

        # All remaining code paths require requesting self-signed tokens.
        return false unless Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])

        # Permit self-signed tokens in development for testing purposes.
        return true if Rails.env.development?

        # Use self-signed tokens if customers are using self-hosted models
        ::Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
      end
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
    end
  end
end
