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
          required: true,
          description: 'Global ID of the namespace the user is acting on.'

        def resolve(root_namespace_id:)
          namespace = authorized_find!(id: root_namespace_id)

          result = ::Ai::ModelSelection::FetchModelDefinitionsService
                     .new(current_user, model_selection_scope: namespace)
                     .execute
          return { default_model: nil, selectable_models: [] } unless result&.success?

          feature_settings = result["unit_primitives"].find do |setting|
            setting["feature_setting"] == "duo_agent_platform"
          end

          return { default_model: nil, selectable_models: [] } unless feature_settings

          models = result["models"]
          identifiers = feature_settings["selectable_models"]
          duo_chat_models = models
            .select { |model| identifiers.include?(model["identifier"]) }
            .map { |model| { name: model["name"], ref: model["identifier"] } }

          default_model = duo_chat_models.find do |model|
            model[:ref] == feature_settings["default_model"]
          end

          {
            default_model: default_model,
            selectable_models: duo_chat_models
          }
        end
      end
    end
  end
end
