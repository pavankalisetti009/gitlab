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
          return { default_model: nil, selectable_models: [], pinned_model: nil } unless result&.success?

          feature_settings = result["unit_primitives"].find do |setting|
            setting["feature_setting"] == "duo_agent_platform"
          end

          return { default_model: nil, selectable_models: [], pinned_model: nil } unless feature_settings

          models = result["models"]
          identifiers = feature_settings["selectable_models"]
          duo_agent_platform_models = models
            .select { |model| identifiers.include?(model["identifier"]) }
            .map { |model| { name: model["name"], ref: model["identifier"] } }

          default_model = duo_agent_platform_models.find do |model|
            model[:ref] == feature_settings["default_model"]
          end

          {
            default_model: default_model,
            selectable_models: duo_agent_platform_models,
            pinned_model: pinned_model_data(namespace, duo_agent_platform_models)
          }
        end

        private

        def pinned_model_data(namespace, duo_agent_platform_models)
          feature_setting_result = ::Ai::FeatureSettingSelectionService
                                     .new(current_user, :duo_agent_platform, namespace)
                                     .execute

          return unless feature_setting_result.success? &&
            feature_setting_result.payload.present? && feature_setting_result.payload.pinned_model?

          pinned_model_identifier = feature_setting_result.payload.offered_model_ref
          return if pinned_model_identifier.blank?

          duo_agent_platform_models.find { |model| model[:ref] == pinned_model_identifier }
        end
      end
    end
  end
end
