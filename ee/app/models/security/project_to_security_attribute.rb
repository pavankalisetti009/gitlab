# frozen_string_literal: true

module Security
  class ProjectToSecurityAttribute < ::SecApplicationRecord
    self.table_name = 'project_to_security_attributes'

    include BulkInsertSafe

    belongs_to :project, optional: false, inverse_of: :project_to_security_attributes
    belongs_to :security_attribute, class_name: 'Security::Attribute', optional: false,
      inverse_of: :project_to_security_attributes

    validates :traversal_ids, presence: true
    validates :security_attribute_id, uniqueness: { scope: :project_id }
    validate :same_root_ancestor

    scope :by_attribute_id, ->(attribute_id) { where(security_attribute_id: attribute_id) }
    scope :by_project_id, ->(project_id) { where(project_id: project_id) }
    scope :id_after, ->(id) { where(arel_table[:id].gt(id)) }
    scope :order_by_project_and_id, ->(direction = :asc) { order(project_id: direction, id: direction) }
    scope :excluding_root_namespace, ->(root_namespace_id) {
      where(sanitize_sql_array(["traversal_ids[1] != ?", root_namespace_id]))
    }

    def self.pluck_id(limit = MAX_PLUCK)
      limit(limit).pluck(:id)
    end

    def self.pluck_security_attribute_id(limit = MAX_PLUCK)
      limit(limit).pluck(:security_attribute_id)
    end

    private

    def same_root_ancestor
      return unless project&.namespace && security_attribute&.namespace
      return if project.namespace.root_ancestor == security_attribute.namespace

      errors.add(:base, 'Project and attribute must belong to the same namespace')
    end
  end
end
