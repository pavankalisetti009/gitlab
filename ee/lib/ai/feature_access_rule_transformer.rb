# frozen_string_literal: true

module Ai
  module FeatureAccessRuleTransformer
    # Transforms grouped feature access rules into presentation format
    def self.transform(feature_rules)
      feature_rules.map do |_, rules|
        through_namespace = rules.first.through_namespace
        {
          through_namespace: {
            id: through_namespace.id,
            name: through_namespace.name,
            full_path: through_namespace.full_path
          },
          features: rules.map(&:accessible_entity)
        }
      end
    end
  end
end
