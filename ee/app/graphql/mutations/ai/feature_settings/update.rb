# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      class Update < Base
        graphql_name 'AiFeatureSettingUpdate'
        description "Updates or creates settings for AI features."

        argument :features, [::Types::Ai::FeatureSettings::FeaturesEnum],
          required: true,
          description: 'Array of AI features being configured (for single or batch update).'

        argument :provider, ::Types::Ai::FeatureSettings::ProvidersEnum,
          required: true,
          description: 'Provider for AI setting.'

        argument :ai_self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model providing the AI setting.'

        argument :offered_model_ref, GraphQL::Types::String,
          required: false,
          description: 'Identifier of the selected model for the feature.'

        def resolve(**args)
          raise_argument_not_available_if!(args, :ai_self_hosted_model_id) { !self_hosted_models? }
          raise_argument_not_available_if!(args, :offered_model_ref) { !gitlab_models? }

          return { ai_feature_settings: [], errors: ['At least one feature is required'] } if args[:features].empty?

          upsert_args = args.dup
          upsert_args.delete(:features)

          self_hosted_model_gid = upsert_args[:ai_self_hosted_model_id]
          if self_hosted_model_gid
            upsert_args[:ai_self_hosted_model_id] = GitlabSchema.parse_gid(self_hosted_model_gid)&.model_id
          end

          results = args[:features].map { |feature| update_model_selection(feature, upsert_args) }

          errors = results.select(&:error?).flat_map(&:errors)
          feature_settings = results.reject(&:error?).flat_map(&:payload)

          decorated_feature_settings = ::Gitlab::Graphql::Representation::AiFeatureSetting
            .decorate(feature_settings, with_self_hosted_models: self_hosted_models?,
              with_gitlab_models: gitlab_models?, model_definitions: gitlab_model_definitions)

          {
            ai_feature_settings: decorated_feature_settings,
            errors: errors
          }
        end

        private

        def self_hosted_models?
          Ability.allowed?(current_user, :manage_self_hosted_models_settings)
        end

        def gitlab_models?
          Ability.allowed?(current_user, :manage_instance_model_selection)
        end

        def update_model_selection(feature, args)
          ::Ai::ModelSelection::UpdateSelfManagedModelSelectionService.new(
            current_user, args.merge(feature: feature)
          ).execute
        end

        def gitlab_model_definitions
          return unless Feature.enabled?(:instance_level_model_selection, :instance)

          response = ::Ai::ModelSelection::FetchModelDefinitionsService
                      .new(current_user, model_selection_scope: nil)
                      .execute

          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(response.payload)
        end

        def raise_argument_not_available_if!(args, attribute)
          return unless args[attribute] && yield

          raise ::Gitlab::Graphql::Errors::ArgumentError,
            format(s_("You don't have permission to update the setting %{attribute}."), attribute: attribute)
        end
      end
    end
  end
end
