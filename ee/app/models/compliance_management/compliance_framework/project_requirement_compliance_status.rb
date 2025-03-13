# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectRequirementComplianceStatus < ApplicationRecord
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
    end
  end
end
