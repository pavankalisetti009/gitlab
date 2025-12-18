# frozen_string_literal: true

module Ai
  class FeatureAccessRule < ApplicationRecord
    include FeatureAccessRuleable

    self.table_name = 'ai_instance_accessible_entity_rules'

    belongs_to :through_namespace,
      class_name: 'Namespace',
      inverse_of: :accessible_ai_features_on_instance
  end
end
