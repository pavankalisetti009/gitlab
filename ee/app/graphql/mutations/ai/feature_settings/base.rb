# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      # rubocop: disable GraphQL/GraphqlName -- It's an abstraction not meant to be used in the schema
      class Base < BaseMutation
        field :ai_feature_settings,
          [::Types::Ai::FeatureSettings::FeatureSettingType],
          null: false,
          description: 'List of AI feature settings after mutation.'
      end
      # rubocop: enable GraphQL/GraphqlName
    end
  end
end
