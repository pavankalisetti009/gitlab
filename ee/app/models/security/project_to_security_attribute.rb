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
    scope :pluck_attribute_id, -> { limit(MAX_PLUCK).pluck(:security_attribute_id) }

    private

    def same_root_ancestor
      return unless project&.namespace && security_attribute&.namespace
      return if project.namespace.root_ancestor == security_attribute.namespace

      errors.add(:base, 'Project and attribute must belong to the same namespace')
    end
  end
end
