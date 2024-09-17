# frozen_string_literal: true

module Resolvers
  module Ai
    module SelfHostedModels
      class FeatureSettingsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type [::Types::Ai::FeatureSettings::FeatureSettingType.connection_type], null: false

        argument :self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: true,
          description: 'Global ID of the self-hosted model.'

        def resolve(self_hosted_model_id:)
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
          unless Feature.enabled?(:ai_custom_model)
            raise_resource_not_available_error!("The 'ai_custom_model' feature is not enabled.")
          end
          # rubocop:enable Gitlab/FeatureFlagWithoutActor

          raise_resource_not_available_error! unless Ability.allowed?(current_user, :manage_ai_settings)

          self_hosted_model = find_self_hosted_model(id: self_hosted_model_id)
          unless self_hosted_model
            raise_resource_not_available_error!("The specified self-hosted model does not exist.")
          end

          ::Ai::FeatureSetting.for_self_hosted_model(self_hosted_model_id.model_id)
        end

        private

        def find_self_hosted_model(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Ai::SelfHostedModel).sync
        end
      end
    end
  end
end
