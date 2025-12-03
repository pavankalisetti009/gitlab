# frozen_string_literal: true

module Gitlab
  module Graphql
    module Representation
      module ModelSelection
        class FeatureSetting < SimpleDelegator
          class << self
            def decorate(feature_settings, model_definitions: nil, current_user: nil, group_id: nil)
              return [] unless feature_settings.present?

              feature_settings.filter_map do |feature_setting|
                decorator = new(feature_setting,
                  model_definitions: model_definitions,
                  current_user: current_user,
                  group_id: group_id
                )

                next if decorator.feature_data.nil?

                if model_definitions.present? || feature_setting.model_definitions.present?
                  decorator.decorate_default_model

                  decorator.decorate_selectable_models
                end

                next decorator
              end
            end
          end

          attr_accessor :feature_setting, :default_model, :selectable_models, :model_definitions
          attr_reader :current_user, :group_id

          def initialize(feature_setting, model_definitions: nil, current_user: nil, group_id: nil)
            @feature_setting = feature_setting
            @model_definitions = model_definitions || feature_setting.model_definitions
            @current_user = current_user
            @group_id = group_id
            super(feature_setting)
          end

          def feature_data
            @feature_data ||= model_definitions['unit_primitives'].find do |unit|
              unit['feature_setting'] == feature_setting.feature.to_s
            end
          end

          def decorate_default_model
            model_ref = feature_data['default_model']
            model_data = find_single_model_data(model_ref)
            @default_model = model_data.presence
          end

          def decorate_selectable_models
            base_refs = feature_data['selectable_models']
            dev_refs  = use_dev_overrides? ? (dev_config['selectable_models'] || []) : []

            model_refs = (base_refs + dev_refs).reject(&:blank?).uniq
            @selectable_models = model_refs.filter_map { |model_ref| find_single_model_data(model_ref) }
          end

          private

          def use_dev_overrides?
            return false unless Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
            return false unless current_user&.gitlab_team_member?
            return false unless dev_config.present?

            dev_group_ids = dev_config['group_ids']
            return false if dev_group_ids.blank?

            dev_group_ids.include?(group_id)
          end

          def find_single_model_data(model_ref)
            model_data = model_data_list.find { |model| model['identifier'] == model_ref }

            raise ArgumentError, 'Model reference was not found in the model definition' unless model_data

            {
              ref: model_data['identifier'],
              name: model_data['name'],
              model_provider: model_data['provider'],
              model_description: model_data['description'],
              cost_indicator: model_data['cost_indicator']
            }
          end

          def model_data_list
            @model_data_list ||= model_definitions['models']
          end

          def dev_config
            @dev_config ||= feature_data['dev']
          end
        end
      end
    end
  end
end
