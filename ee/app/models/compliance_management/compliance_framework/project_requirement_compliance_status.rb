# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectRequirementComplianceStatus < ApplicationRecord
      include EachBatch

      belongs_to :compliance_framework, class_name: 'ComplianceManagement::Framework'
      belongs_to :project
      belongs_to :namespace
      belongs_to :compliance_requirement

      validates :project_id, uniqueness: { scope: :compliance_requirement_id }
      validates_presence_of :pass_count, :fail_count, :pending_count, :project, :namespace,
        :compliance_requirement, :compliance_framework

      validates :pass_count, :fail_count, :pending_count,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      scope :order_by_updated_at_and_id, ->(direction = :asc) { order(updated_at: direction, id: direction) }

      scope :in_optimization_array_mapping_scope, ->(id_expression) {
        where(arel_table[:namespace_id].eq(id_expression))
      }
      scope :in_optimization_finder_query, ->(_project_id_expression, id_expression) {
        where(arel_table[:id].eq(id_expression))
      }
      scope :for_projects, ->(project_ids) { where(project_id: project_ids) }
      scope :for_requirements, ->(requirement_ids) { where(compliance_requirement_id: requirement_ids) }
      scope :for_frameworks, ->(framework_ids) { where(compliance_framework_id: framework_ids) }

      def self.delete_all_project_statuses(project_id)
        where(project_id: project_id).each_batch(of: 100) do |batch|
          batch.delete_all
        end
      end
    end
  end
end
