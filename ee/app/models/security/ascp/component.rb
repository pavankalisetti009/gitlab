# frozen_string_literal: true

module Security
  module Ascp
    class Component < ::SecApplicationRecord
      self.table_name = 'ascp_components'

      belongs_to :project
      belongs_to :scan, class_name: 'Security::Ascp::Scan'

      has_one :security_context, class_name: 'Security::Ascp::SecurityContext', inverse_of: :component
      has_many :dependencies, class_name: 'Security::Ascp::ComponentDependency', inverse_of: :component
      has_many :dependents, class_name: 'Security::Ascp::ComponentDependency',
        foreign_key: :dependency_id, inverse_of: :dependency

      validates :project, :scan, :title, :sub_directory, presence: true
      validates :sub_directory, uniqueness: { scope: [:project_id, :scan_id] }

      scope :by_project, ->(project_id) { where(project_id: project_id) }
      scope :at_scan, ->(scan_id) { where(scan_id: scan_id) }
    end
  end
end
