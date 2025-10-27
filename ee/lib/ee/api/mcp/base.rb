# frozen_string_literal: true

module EE
  module API
    module Mcp
      module Base
        extend ActiveSupport::Concern

        prepended do
          helpers do
            extend ::Gitlab::Utils::Override

            override :feature_available?
            def feature_available?
              return false unless instance_allows_experiment_and_beta_features
              return false unless gitlab_com_namespace_enables_experiment_and_beta_features

              true
            end

            def instance_allows_experiment_and_beta_features
              return true if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

              ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
            end

            def gitlab_com_namespace_enables_experiment_and_beta_features
              # namespace-level settings check is only relevant for .com
              return true unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

              current_user.any_group_with_ai_available?
            end
          end
        end
      end
    end
  end
end
