# frozen_string_literal: true

module Ai
  module ModelSelection
    class NamespaceFeatureSetting < ApplicationRecord
      include ::Ai::ModelSelection::FeaturesConfigurable
      include CascadingNamespaceSettingAttribute

      self.table_name = "ai_namespace_feature_settings"

      belongs_to :namespace, class_name: '::Group', inverse_of: :ai_feature_settings

      validates :feature, uniqueness: { scope: :namespace_id }

      validate :validate_root_namespace

      scope :for_namespace, ->(self_hosted_model_id) { where(namespace_id: self_hosted_model_id) }

      def self.find_or_initialize_by_feature(namespace, feature)
        return unless ::Feature.enabled?(:ai_model_switching, namespace)
        return unless namespace.root?

        find_or_initialize_by(namespace_id: namespace.id, feature: feature)
      end

      def model_selection_scope
        namespace
      end

      private

      def validate_root_namespace
        return if namespace&.root?

        errors.add(:namespace,
          'Model selection is only available for top-level namespaces.')
      end
    end
  end
end
