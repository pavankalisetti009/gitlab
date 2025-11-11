# frozen_string_literal: true

module Resolvers
  module Ai
    module FeatureSettings
      class FeatureSettingsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Ai::FeatureSettings::FeatureSettingType.connection_type, null: false

        argument :self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model.'

        def resolve(self_hosted_model_id: nil)
          feature_settings = get_feature_settings(self_hosted_model_id)

          ::Gitlab::Graphql::Representation::AiFeatureSetting
            .decorate(feature_settings,
              with_self_hosted_models: self_hosted_models?,
              with_gitlab_models: gitlab_models?,
              model_definitions: gitlab_model_definitions)
        end

        private

        def get_feature_settings(self_hosted_model_id)
          ::Ai::FeatureSettings::FeatureSettingFinder.new(self_hosted_model_id: self_hosted_model_id).execute
        end

        def self_hosted_models?
          self_hosted_models_requested = context.query.sanitized_query_string.include?('validModels')

          return false unless self_hosted_models_requested

          Ability.allowed?(current_user, :manage_self_hosted_models_settings)
        end

        def gitlab_models?
          gitlab_models_requested = context.query.sanitized_query_string.include?('validGitlabModels')

          return false unless gitlab_models_requested

          Ability.allowed?(current_user, :manage_instance_model_selection)
        end

        def gitlab_model_definitions
          return unless Feature.enabled?(:instance_level_model_selection, :instance)

          result = ::Ai::ModelSelection::FetchModelDefinitionsService
            .new(current_user, model_selection_scope: nil)
            .execute

          return unless result&.success? && result.payload

          # GitLab Duo CLI (glab_ask_git_command) does not currently work with GitLab vendored models so they need
          # to be filtered out until there's a fix https://gitlab.com/gitlab-org/gitlab/-/issues/578924
          result.payload["unit_primitives"].reject! { |item| item["feature_setting"] == "glab_ask_git_command" }

          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(result.payload)
        end
      end
    end
  end
end
