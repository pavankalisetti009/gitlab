# frozen_string_literal: true

module Ai
  module ModelSelection
    class InstanceModelSelectionFeatureSetting < ApplicationRecord
      include ::Ai::ModelSelection::FeaturesConfigurable

      self.table_name = "instance_model_selection_feature_settings"

      validates :feature, uniqueness: true

      scope :non_default, -> { where.not(offered_model_ref: [nil, ""]) }

      def self.find_or_initialize_by_feature(feature)
        feature_name = get_feature_name(feature)
        find_or_initialize_by(feature: feature_name)
      end

      def model_selection_scope
        :instance
      end

      def base_url
        ::Gitlab::AiGateway.cloud_connector_url
      end

      def vendored?
        true
      end
    end
  end
end
