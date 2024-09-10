# frozen_string_literal: true

module Types
  module Ai
    module FeatureSettings
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class FeatureSettingType < ::Types::BaseObject
        graphql_name 'AiFeatureSetting'
        description 'Duo Chat feature setting'

        field :feature, String, null: false, description: 'AI feature.'

        field :provider, String, null: false, description: 'Chosen method to provide the feature.'

        field :self_hosted_model,
          Types::Ai::SelfHostedModels::SelfHostedModelType,
          null: true,
          description: 'Self-hosted model server which provide the feature.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
