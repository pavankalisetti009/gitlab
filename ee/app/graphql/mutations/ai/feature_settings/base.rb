# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      # rubocop: disable GraphQL/GraphqlName -- It's an abstraction not meant to be used in the schema
      class Base < BaseMutation
        field :ai_feature_setting,
          ::Types::Ai::FeatureSettings::FeatureSettingType,
          null: true,
          description: 'AI feature setting after mutation.'

        private

        def check_feature_access!
          raise_resource_not_available_error! unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

          raise_resource_not_available_error! unless Ability.allowed?(current_user, :manage_ai_settings)
        end
      end
      # rubocop: enable GraphQL/GraphqlName
    end
  end
end
