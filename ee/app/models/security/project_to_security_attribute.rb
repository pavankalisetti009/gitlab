# frozen_string_literal: true

module Security
  class ProjectToSecurityAttribute < ::SecApplicationRecord
    self.table_name = 'project_to_security_attributes'

    belongs_to :project, optional: false
    belongs_to :security_attribute, class_name: 'Security::Attribute', optional: false

    validates :traversal_ids, presence: true
    validates :security_attribute_id, uniqueness: { scope: :project_id }
  end
end
