# frozen_string_literal: true

module Resolvers
  module Ai
    module Chat
      class AvailableModelsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorize :access_duo_agentic_chat

        type ::Types::Ai::Chat::AvailableModelsType, null: false

        argument :root_namespace_id,
          ::Types::GlobalIDType[::Group],
          required: false,
          description: 'Global ID of the namespace the user is acting on.'

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          required: false,
          description: 'Global ID of the project the user is acting on.'

        def resolve(root_namespace_id: nil, project_id: nil)
          if project_id
            project = authorized_find!(id: project_id)
            namespace = project.root_namespace
          else
            namespace = authorized_find!(id: root_namespace_id)
          end

          result = ::Ai::ModelSelection::FetchModelDefinitionsService
                     .new(current_user, model_selection_scope: namespace)
                     .execute

          return empty_result unless result&.success?

          model_definitions = result.payload

          feature_setting = feature_setting_result(namespace)
          # Without a feature setting record, we can't really perform any calculations,
          # so let's return an empty result if it's not present
          return empty_result unless feature_setting.present?

          decorated = ::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting
                        .decorate([feature_setting].compact, model_definitions: model_definitions)

          decorator_result = decorated.find do |object|
            object.feature_setting&.feature&.to_sym == feature_setting.feature.to_sym
          end

          # If we don't find a decorator for the feature setting, we can't really perform any calculations,
          # so let's return an empty result
          return empty_result unless decorator_result.present?

          selectable_models = decorator_result.selectable_models

          {
            default_model: decorator_result.default_model,
            selectable_models: selectable_models,
            pinned_model: pinned_model_data(feature_setting, selectable_models)
          }
        end

        private

        def empty_result
          { default_model: nil, selectable_models: [], pinned_model: nil }
        end

        def feature_setting_result(namespace)
          result = ::Ai::FeatureSettingSelectionService
            .new(current_user, ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name, namespace)
            .execute

          return unless result.success? && result.payload.present?

          result.payload
        end

        def pinned_model_data(feature_setting, duo_agent_platform_models)
          return unless feature_setting.present?
          return unless feature_setting.user_model_selection_available?
          return unless feature_setting.pinned_model?

          pinned_model_identifier = feature_setting.offered_model_ref
          return if pinned_model_identifier.blank?

          duo_agent_platform_models.find { |model| model[:ref] == pinned_model_identifier }
        end
      end
    end
  end
end
