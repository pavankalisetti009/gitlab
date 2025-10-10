# frozen_string_literal: true

module Gitlab
  module Graphql
    module Representation
      class AiFeatureSetting < SimpleDelegator
        class << self
          include Gitlab::Utils::StrongMemoize

          def decorate(
            feature_settings, with_self_hosted_models: false, with_gitlab_models: false,
            model_definitions: nil)
            return [] unless feature_settings.present?

            feature_settings.map do |feature_setting|
              new(
                feature_setting,
                **valid_model_params(feature_setting, with_self_hosted_models),
                **gitlab_managed_models_params(feature_setting, model_definitions, with_gitlab_models)
              )
            end
          end

          private

          def valid_model_params(feature_setting, with_valid_models)
            return {} unless with_valid_models

            compatible_llms = feature_setting.compatible_llms || []

            indexed_self_hosted_models = ::Ai::SelfHostedModel.all.group_by(&:model)

            valid_models = compatible_llms.flat_map do |model|
              indexed_self_hosted_models[model] || []
            end

            valid_models = valid_models.filter(&:ga?) unless beta_models_enabled?

            {
              valid_models: valid_models.sort_by(&:name)
            }
          end

          def gitlab_managed_models_params(feature_setting, model_definitions, with_valid_models)
            return {} unless model_definitions

            feature_name = feature_setting.feature

            model_ref = nil

            if feature_setting.vendored?
              model_ref = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting
                .find_or_initialize_by_feature(feature_name)
                .offered_model_ref
            end

            definition = model_definitions.definition_for_feature(feature_name)

            return {} unless definition

            valid_models = []

            if with_valid_models
              valid_models = definition['selectable_models']
                               .map { |ref| model_definitions.model_with_ref(ref) }
            end

            {
              gitlab_model: model_definitions.model_with_ref(model_ref),
              default_gitlab_model: model_definitions.model_with_ref(definition && definition['default_model']),
              valid_gitlab_models: valid_models
            }
          end

          def beta_models_enabled?
            ::Ai::TestingTermsAcceptance.has_accepted?
          end
        end

        attr_accessor :feature_setting, :valid_models, :valid_gitlab_models, :gitlab_model, :default_gitlab_model

        def initialize(
          feature_setting, valid_models: [], valid_gitlab_models: [], gitlab_model: nil,
          default_gitlab_model: nil)
          @feature_setting = feature_setting
          @valid_models = valid_models
          @valid_gitlab_models = valid_gitlab_models
          @default_gitlab_model = default_gitlab_model
          @gitlab_model = gitlab_model

          super(feature_setting)
        end
      end
    end
  end
end
