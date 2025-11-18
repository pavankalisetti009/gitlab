# frozen_string_literal: true

module Gitlab
  module Ai
    module ModelSelection
      class ModelDefinitionResponseParser
        include Gitlab::Utils::StrongMemoize

        def initialize(model_definitions)
          @definitions = model_definitions
        end

        attr_reader :definitions

        def model_with_ref(ref)
          return unless definitions

          gitlab_models_by_ref[ref]
        end

        def definition_for_feature(feature)
          return unless definitions

          model_definition_per_feature[feature.to_s]
        end

        def selectable_models_for_feature(feature)
          feature_definition = definition_for_feature(feature)

          return [] if feature_definition.blank?

          feature_definition['selectable_models']
        end

        def gitlab_models_by_ref
          return unless definitions && definitions['models']

          definitions['models'].to_h do |model|
            [
              model['identifier'],
              {
                'name' => model['name'],
                'ref' => model['identifier'],
                'model_provider' => model['provider']
              }
            ]
          end
        end
        strong_memoize_attr :gitlab_models_by_ref

        def model_definition_per_feature
          return unless definitions && definitions['unit_primitives']

          definitions['unit_primitives'].index_by { |up| up['feature_setting'] }
        end
        strong_memoize_attr :model_definition_per_feature
      end
    end
  end
end
