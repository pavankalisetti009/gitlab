# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumer < ApplicationRecord
      self.table_name = "ai_catalog_item_consumers"

      validates :enabled, :locked, inclusion: { in: [true, false] }

      validates :pinned_version_prefix, length: { maximum: 50 }

      validate :validate_exactly_one_sharding_key_present
      validate :validate_organization_match
      validate :validate_item_privacy_allowed, if: :item_changed?
      validate :validate_service_account, if: :service_account_id?
      validate :validate_parent_item_consumer, if: :parent_item_consumer_id?

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
      belongs_to :parent_item_consumer, class_name: 'Ai::Catalog::ItemConsumer'
      belongs_to :service_account, class_name: 'User'

      has_one :flow_trigger, class_name: 'Ai::FlowTrigger', inverse_of: :ai_catalog_item_consumer

      validates :service_account, absence: true, unless: -> { item&.flow? || item&.third_party_flow? }
      validates :parent_item_consumer, absence: true, unless: -> { item&.flow? || item&.third_party_flow? }

      scope :by_enabled, ->(enabled) { where(enabled: enabled) }

      accepts_nested_attributes_for :flow_trigger

      scope :not_for_projects, ->(project) { where.not(project: project) }
      scope :for_projects, ->(project) { where(project: project) }
      scope :for_item, ->(item_id) { where(ai_catalog_item_id: item_id) }
      scope :with_item_type, ->(item_type) { joins(:item).where(item: { item_type: item_type }) }

      private

      def organization_id_from_sharding_key
        organization_id || group&.organization_id || project&.organization_id
      end

      def validate_organization_match
        return if ai_catalog_item_id.nil? || item.organization_id == organization_id_from_sharding_key

        errors.add(:item, s_("AICatalog|organization must match the item consumer's organization"))
      end

      def validate_exactly_one_sharding_key_present
        return if [organization, group, project].compact.one?

        errors.add(:base, s_('AICatalog|The item consumer must belong to only one organization, group, or project'))
      end

      def validate_item_privacy_allowed
        return if item.public? || item.project.nil?
        return if project && item.project == project
        return if group && item.project.root_group == group

        errors.add(:item, s_('AICatalog|is private to another project'))
      end

      def validate_service_account
        if group.nil? || !group.root?
          errors.add(:service_account, s_('AICatalog|can be set only for top-level group consumers'))
          return
        end

        errors.add(:service_account, s_('AICatalog|must be a service account')) unless service_account.service_account?

        return unless service_account.provisioned_by_group_id != group_id

        errors.add(:service_account, s_('AICatalog|must be provisioned by the group'))
      end

      def validate_parent_item_consumer
        if project.nil?
          errors.add(:parent_item_consumer, s_('AICatalog|can be set only for project consumers'))
          return
        end

        return if parent_item_consumer.group == project.root_ancestor

        errors.add(:parent_item_consumer, s_("AICatalog|must belong to this project's top-level group"))
      end
    end
  end
end
