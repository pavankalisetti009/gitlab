# frozen_string_literal: true

module Ai
  class NamespaceFeatureAccessRule < ApplicationRecord
    include FeatureAccessRuleable

    self.table_name = 'ai_namespace_feature_access_rules'

    belongs_to :through_namespace,
      class_name: 'Namespace',
      inverse_of: :ai_feature_rules_through_namespace

    belongs_to :root_namespace,
      class_name: 'Namespace',
      inverse_of: :ai_feature_rules

    validates :root_namespace_id, presence: true

    validate :through_namespace_root_is_root_namespace

    private

    def through_namespace_root_is_root_namespace
      return if through_namespace.blank? || root_namespace.blank?
      return if through_namespace.root_ancestor.id == root_namespace_id

      errors.add(:through_namespace, 'must belong to the same root namespace as the root_namespace')
    end
  end
end
