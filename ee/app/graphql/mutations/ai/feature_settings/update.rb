# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      class Update < Base
        graphql_name 'AiFeatureSettingUpdate'
        description "Updates or create setting for the AI feature."

        argument :feature, ::Types::Ai::FeatureSettings::FeaturesEnum,
          required: true,
          description: 'AI feature being configured.'

        argument :provider, ::Types::Ai::FeatureSettings::ProvidersEnum,
          required: true,
          description: 'Provider for AI setting.'

        argument :self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model provide the AI setting.'

        def resolve(**args)
          check_feature_access!

          feature_setting = upsert_feature_setting(args)

          if feature_setting.errors.present?
            {
              ai_feature_setting: nil,
              errors: Array(feature_setting.errors)
            }
          else
            { ai_feature_setting: feature_setting, errors: [] }
          end
        end

        private

        def upsert_feature_setting(args)
          feature_setting = find_object(feature: args[:feature])
          self_hosted_model_id = args[:self_hosted_model_id]

          feature_setting.assign_attributes(**args.except(:self_hosted_model_id))

          if self_hosted_model_id
            self_hosted_model = find_self_hosted_model(id: self_hosted_model_id)
            feature_setting.self_hosted_model = self_hosted_model if self_hosted_model
          end

          feature_setting.save

          feature_setting
        end

        def find_object(feature:)
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end

        def find_self_hosted_model(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Ai::SelfHostedModel).sync
        end
      end
    end
  end
end
