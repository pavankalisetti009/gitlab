# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumer < ApplicationRecord
      include AfterCommitQueue

      self.table_name = "ai_catalog_item_consumers"

      validates :enabled, :locked, inclusion: { in: [true, false] }

      validates :pinned_version_prefix, length: { maximum: 50 }

      validates_with ExactlyOnePresentValidator, fields: :sharding_keys,
        message: ->(_fields) {
          s_('AICatalog|The item consumer must belong to only one organization, group, or project')
        }
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
      validates :service_account, uniqueness: true, allow_nil: true

      scope :by_enabled, ->(enabled) { where(enabled: enabled) }

      accepts_nested_attributes_for :flow_trigger

      scope :not_for_projects, ->(project) { where.not(project: project) }
      scope :for_projects, ->(projects) { where(project: projects) }
      scope :for_groups, ->(groups) { where(group: groups) }
      scope :for_container_item_pairs, ->(container_type, container_item_pairs) do
        raise ArgumentError, "Unknown container_type: #{container_type}" unless container_type.in?([:project, :group])

        columns = [:"#{container_type}_id", :ai_catalog_item_id]
        where(columns => container_item_pairs)
      end

      scope :for_item, ->(item_id) { where(ai_catalog_item_id: item_id) }
      scope :with_item_type, ->(item_type) { joins(:item).where(item: { item_type: item_type }) }
      scope :with_items, -> { includes(:item) }

      scope :order_by_catalog_priority, -> do
        order_columns = []

        # First priority: foundational flows
        # Note: We don't create item_consumer records for foundational agents
        order_columns << Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'foundational_flow_reference',
          order_expression: Arel.sql("item.foundational_flow_reference").asc,
          nullable: :nulls_last,
          order_direction: :asc,
          add_to_projections: true
        )

        # Second priority: order by id DESC
        order_columns << Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: arel_table[:id].desc,
          nullable: :not_nullable
        )

        joins(:item).reorder(Gitlab::Pagination::Keyset::Order.build(order_columns))
      end

      scope :for_catalog_items, ->(item_ids) { where(ai_catalog_item_id: item_ids) }
      scope :for_service_account, ->(service_account_id) { where(service_account_id:) }
      scope :with_service_account, -> { preload(:service_account) }
      scope :with_items_configurable_for_project, ->(project_id) {
        joins(:item).where(item: { public: true }).or(where(item: { project_id: project_id }))
      }

      def self.exists_for_service_account_and_project_id?(service_account, project_id)
        parent_item_consumers = for_service_account(service_account)

        exists?(parent_item_consumer: parent_item_consumers, project_id: project_id)
      end

      def pinned_version
        @pinned_version ||= item.resolve_version(pinned_version_prefix)
      end

      private

      def sharding_keys
        [:organization, :group, :project]
      end

      def organization_id_from_sharding_key
        organization_id || group&.organization_id || project&.organization_id
      end

      def validate_organization_match
        return if ai_catalog_item_id.nil? || item.organization_id == organization_id_from_sharding_key

        errors.add(:item, s_("AICatalog|organization must match the item consumer's organization"))
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
