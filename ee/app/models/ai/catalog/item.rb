# frozen_string_literal: true

module Ai
  module Catalog
    class Item < ApplicationRecord
      include ActiveRecord::Sanitization::ClassMethods
      include Gitlab::SQL::Pattern

      # Temporarily pin certain items to the first page of the catalog.
      # This is to be a temporary method that can be replaced by an improved
      # feature such as:
      # https://gitlab.com/groups/gitlab-org/-/epics/19577
      GITLAB_ITEM_IDS = [104, 105, 348, 356].freeze

      self.table_name = "ai_catalog_items"

      validates :organization, :latest_version, :item_type, :description, :name, :verification_level, presence: true

      validates :name, length: { minimum: 3, maximum: 255 }, allow_nil: true
      validates :description, length: { maximum: 1_024 }, allow_nil: true

      validates_inclusion_of :public, in: [true, false]
      validate :validate_public_item_cannot_become_private

      belongs_to :organization, class_name: 'Organizations::Organization', optional: false
      belongs_to :project
      belongs_to :latest_version, class_name: 'Ai::Catalog::ItemVersion', optional: false, autosave: true
      belongs_to :latest_released_version, class_name: 'Ai::Catalog::ItemVersion', optional: true

      validate :organization_match

      has_many :versions, class_name: 'Ai::Catalog::ItemVersion', foreign_key: :ai_catalog_item_id, inverse_of: :item
      has_many :consumers, class_name: 'Ai::Catalog::ItemConsumer', foreign_key: :ai_catalog_item_id, inverse_of: :item

      has_many(
        :dependents,
        foreign_key: :dependency_id, inverse_of: :dependency, class_name: 'Ai::Catalog::ItemVersionDependency'
      )

      enum :verification_level, ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS

      scope :for_verification_level, ->(level) { where(verification_level: level) }
      scope :for_organization, ->(organization) { where(organization: organization) }
      scope :for_project, ->(project) { where(project: project) }
      scope :not_deleted, -> { where(deleted_at: nil) }
      scope :public_only, -> { where(public: true) }
      scope :search, ->(query) { fuzzy_search(query, [:name, :description]) }
      scope :with_ids, ->(ids) { where(id: ids) }
      scope :with_item_type, ->(item_type) { where(item_type: item_type) }

      scope :order_by_id_desc, -> do
        return reorder(id: :desc) unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

        gitlab_items = GITLAB_ITEM_IDS.map(&:to_i).join(',')

        order = Gitlab::Pagination::Keyset::Order.build([
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'hard_coded_ids',
            order_expression: Arel.sql("array_position(ARRAY[#{gitlab_items}]::bigint[], id)").asc,
            nullable: :nulls_last,
            order_direction: :asc,
            add_to_projections: true
          ),
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'id',
            order_expression: Item.arel_table[:id].desc,
            nullable: :not_nullable
          )
        ])

        reorder(order)
      end

      before_destroy :prevent_deletion_if_consumers_exist

      AGENT_TYPE = :agent
      FLOW_TYPE = :flow
      THIRD_PARTY_FLOW_TYPE = :third_party_flow

      enum :item_type, {
        AGENT_TYPE => 1,
        FLOW_TYPE => 2,
        THIRD_PARTY_FLOW_TYPE => 3
      }

      class << self
        def public_or_visible_to_user(current_user)
          return public_only if current_user.nil?

          joins(
            sanitize_sql_array([
              'LEFT JOIN project_authorizations pa ON ai_catalog_items.project_id = pa.project_id ' \
                'AND pa.user_id = ? AND pa.access_level >= ?',
              current_user.id,
              Gitlab::Access::DEVELOPER
            ])
          ).where('ai_catalog_items.public = ? OR pa.project_id IS NOT NULL', true)
        end
      end

      def deleted?
        deleted_at.present?
      end

      def private?
        !public?
      end

      def soft_delete
        update(deleted_at: Time.zone.now)
      end

      def definition(pinned_version_prefix = nil, pinned_version_id = nil)
        version = pinned_version_id ? ItemVersion.find(pinned_version_id) : resolve_version(pinned_version_prefix)

        case item_type.to_sym
        when AGENT_TYPE
          AgentDefinition.new(self, version)
        when FLOW_TYPE
          raise ArgumentError, "pinned_version_id is not supported for flows" if pinned_version_id

          FlowDefinition.new(self, version)
        when THIRD_PARTY_FLOW_TYPE
          version.definition
        end
      end

      def resolve_version(pinned_version_prefix = nil)
        # TODO: filter only released versions once possible!
        if pinned_version_prefix.nil?
          latest_version
        elsif pinned_version_prefix.to_s.count('.') == 2
          versions.find_by(version: pinned_version_prefix)
        else
          sanitized_prefix = sanitize_sql_like(pinned_version_prefix)
          # TODO: switch to VersionSorter https://gitlab.com/gitlab-org/gitlab/-/merge_requests/200213#note_2668488811
          versions.where('version LIKE ?', "#{sanitized_prefix}.%").order(id: :desc).first
        end
      end

      def build_new_version(version_params)
        versions.build(version_params).tap do |new_version|
          self.latest_version = new_version
        end
      end

      private

      def prevent_deletion_if_consumers_exist
        return unless consumers.any?

        errors.add(:base, 'Cannot delete an item that has consumers')
        throw :abort # rubocop:disable Cop/BanCatchThrow -- We handle soft deleting in `ee/app/services/ai/catalog/agents/destroy_service.rb`
      end

      def organization_match
        return if project_id.nil? || project.organization_id == organization_id

        errors.add(:project, _("organization must match the item's organization"))
      end

      def validate_public_item_cannot_become_private
        return unless becoming_private?

        # TODO add support for group-level in future https://gitlab.com/gitlab-org/gitlab/-/issues/553912
        # where we would check for any consumers that are not the group, or its descendant groups or projects.
        if has_external_consumers?
          errors.add(:public,
            s_('AICatalog|cannot be changed from public to private as it has catalog consumers')
          )
        end

        return unless used_by_other_flows?

        errors.add(:public,
          s_('AICatalog|cannot be changed from public to private as it is used by other flows')
        )
      end

      def becoming_private?
        public_changed? && public == false && public_was == true
      end

      def has_external_consumers?
        project_id.present? && consumers.not_for_projects(project_id).any?
      end

      def used_by_other_flows?
        dependents.any?
      end
    end
  end
end
