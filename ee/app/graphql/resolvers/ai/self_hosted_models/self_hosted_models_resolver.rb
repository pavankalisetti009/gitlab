# frozen_string_literal: true

module Resolvers
  module Ai
    module SelfHostedModels
      class SelfHostedModelsResolver < BaseResolver
        type ::Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type, null: false

        def resolve(**args)
          return unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
          return unless Ability.allowed?(current_user, :manage_ai_settings)

          if args[:id]
            get_self_hosted_model(args[:id])
          else
            ::Ai::SelfHostedModel.all
          end
        end

        private

        def get_self_hosted_model(self_hosted_model_gid)
          [::Ai::SelfHostedModel.find(self_hosted_model_gid.model_id)]
        end
      end
    end
  end
end
