# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectSettings < ApplicationRecord
      self.table_name = 'project_compliance_framework_settings'

      belongs_to :project
      belongs_to :compliance_management_framework, class_name: "ComplianceManagement::Framework", foreign_key: :framework_id

      validates :project, presence: true

      delegate :full_path, to: :project

      scope :by_framework_and_project, ->(project_id, framework_id) { where(project_id: project_id, framework_id: framework_id) }

      def self.find_or_create_by_project(project, framework)
        find_or_initialize_by(project: project).tap do |setting|
          setting.framework_id = framework.id
          setting.save
        end
      end
    end
  end
end
