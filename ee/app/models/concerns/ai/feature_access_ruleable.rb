# frozen_string_literal: true

module Ai
  module FeatureAccessRuleable
    extend ActiveSupport::Concern

    included do
      include BulkInsertSafe

      validates :through_namespace_id, :accessible_entity, presence: true
      validates :accessible_entity, length: { maximum: 255 },
        uniqueness: { scope: [:through_namespace_id] },
        inclusion: { in: %w[duo_classic duo_agent_platform] }

      alias_attribute :feature, :accessible_entity
    end
  end
end
