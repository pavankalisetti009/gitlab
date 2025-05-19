# frozen_string_literal: true

module Gitlab
  module Graphql
    module Representation
      module ModelSelection
        class FeatureSetting < SimpleDelegator
          class << self
            def decorate(feature_settings)
              return [] unless feature_settings.present?

              feature_settings.map do |feature_setting|
                decorator = new(feature_setting)

                if feature_setting.model_definitions.present?
                  decorator.decorate_default_model

                  decorator.decorate_selectable_models
                end

                next decorator
              end
            end
          end

          attr_accessor :feature_setting, :default_model, :selectable_models

          def initialize(feature_setting, default_model: {}, selectable_models: [])
            @feature_setting = feature_setting
            @default_model = default_model
            @selectable_models = selectable_models

            super(feature_setting)
          end

          def decorate_default_model
            model_ref = feature_data['default_model']

            model_data = find_single_model_data(model_ref)

            @default_model = model_data.presence
          end

          def decorate_selectable_models
            model_refs = feature_data['selectable_models']

            @selectable_models = model_refs.filter_map do |model_ref|
              find_single_model_data(model_ref)
            end
          end

          private

          def find_single_model_data(model_ref)
            model_data = model_data_list.find { |model| model['identifier'] == model_ref }

            raise ArgumentError, 'Model reference was not found in the model definition' unless model_data

            {
              ref: model_data['identifier'],
              name: model_data['name']
            }
          end

          def feature_data
            @feature_data ||= model_definitions['unit_primitives'].find do |unit|
              unit['feature_setting'] == feature_setting.feature.to_s
            end
          end

          def model_data_list
            @model_data_list ||= model_definitions['models']
          end

          def model_definitions
            @model_definition ||= feature_setting.model_definitions
          end
        end
      end
    end
  end
end
