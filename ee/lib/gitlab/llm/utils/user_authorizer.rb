# frozen_string_literal: true

module Gitlab
  module Llm
    module Utils
      class UserAuthorizer
        def initialize(user, project, feature_name)
          @user = user
          @project = project
          @feature_name = feature_name
        end

        def allowed?
          return false unless @user

          project_authorized? && user_authorized?
        end

        private

        def project_authorized?
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: @project,
            feature_name: @feature_name
          ).allowed?
        end

        def user_authorized?
          return true if service.allowed_for?(@user)

          return false unless service.free_access?

          if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
            @user.any_group_with_ga_ai_available?(@feature_name)
          else
            ::License.feature_available?(:ai_features)
          end
        end

        def service
          @service ||= ::CloudConnector::AvailableServices.find_by_name(@feature_name)
        end
      end
    end
  end
end
