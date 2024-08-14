# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module RequestAuthenticator
        extend ::Gitlab::Utils::Override

        private

        override :find_user_for_graphql_api_request
        def find_user_for_graphql_api_request
          find_user_from_geo_token || super
        end

        override :graphql_authorization_scopes
        def graphql_authorization_scopes
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- this is before we auth the user and we may not have project
          if ::Feature.enabled?(:allow_ai_features_token_for_graphql_ai_features)
            super + [:ai_features]
          else
            super
          end
          # rubocop:enable Gitlab/FeatureFlagWithoutActor
        end
      end
    end
  end
end
