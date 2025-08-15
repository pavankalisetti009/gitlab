# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumer < ApplicationRecord
      self.table_name = "ai_catalog_item_consumers"

      validates :enabled, :locked, inclusion: { in: [true, false] }

      validates :pinned_version_prefix, length: { maximum: 50 }

      validate :validate_exactly_one_sharding_key_present
      validate :organization_match

      validates :item, uniqueness: { scope: :organization_id, message: 'already configured' },
        if: -> { organization.present? }
      validates :item, uniqueness: { scope: :group_id, message: 'already configured' },
        if: -> { group.present? }
      validates :item, uniqueness: { scope: :project_id, message: 'already configured' },
        if: -> { project.present? }

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :consumers, optional: false

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :group
      belongs_to :project

      scope :not_for_projects, ->(project) { where.not(project: project) }

      private

      def organization_id_from_sharding_key
        organization_id || group&.organization_id || project&.organization_id
      end

      def organization_match
        return if ai_catalog_item_id.nil? || item.organization_id == organization_id_from_sharding_key

        errors.add(:item, _("organization must match the item consumer's organization"))
      end

      def validate_exactly_one_sharding_key_present
        return if [organization, group, project].compact.one?

        errors.add(:base, 'The item consumer must belong to only one organization, group, or project')
      end
    end
  end
end
