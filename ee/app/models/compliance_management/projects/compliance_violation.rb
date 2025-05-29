# frozen_string_literal: true

module ComplianceManagement
  module Projects
    class ComplianceViolation < ApplicationRecord
      self.table_name = 'project_compliance_violations'
      belongs_to :project
      belongs_to :namespace
      belongs_to :compliance_control,
        class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl',
        foreign_key: 'compliance_requirements_control_id', inverse_of: :project_compliance_violations
      belongs_to :audit_event, class_name: 'AuditEvent'
      has_many :compliance_violation_issues, class_name: 'ComplianceManagement::Projects::ComplianceViolationIssue',
        foreign_key: 'project_compliance_violation_id', inverse_of: :project_compliance_violation
      has_many :issues, through: :compliance_violation_issues

      validates_presence_of :project, :namespace, :compliance_control, :status, :audit_event

      validates :audit_event_id,
        uniqueness: { scope: :compliance_requirements_control_id,
                      message: ->(_object, _data) {
                        _('has already been recorded as a violation for this compliance control')
                      } }

      # Validate associations for data consistency
      validate :project_belongs_to_namespace
      validate :compliance_control_belongs_to_namespace
      validate :audit_event_has_valid_entity_association

      enum :status, { detected: 0, in_review: 1, resolved: 2, dismissed: 3 }

      scope :order_by_created_at_and_id, ->(direction = :asc) { order(created_at: direction, id: direction) }

      private

      def project_belongs_to_namespace
        return unless project && namespace_id

        if project.namespace_id != namespace_id # rubocop:disable Style/GuardClause -- Easier to read
          errors.add(:project, _('must belong to the specified namespace'))
        end
      end

      def compliance_control_belongs_to_namespace
        return unless compliance_control && project

        if compliance_control.namespace_id != project.root_namespace.id # rubocop:disable Style/GuardClause -- Easier to read
          errors.add(:compliance_control, _('must belong to the specified namespace'))
        end
      end

      def audit_event_has_valid_entity_association
        return unless audit_event

        entity = audit_event.entity

        return if entity.is_a?(::Gitlab::Audit::NullEntity)

        case audit_event.entity_type
        when 'Project'
          if project_id && audit_event.entity_id != project_id
            errors.add(:audit_event, _('must reference the specified project as its entity'))
          end
        when 'Group'
          if namespace && namespace.self_and_ancestor_ids.exclude?(audit_event.entity_id)
            errors.add(:audit_event, _('must reference the specified namespace as its entity'))
          end
        else
          errors.add(:audit_event, _('must be associated with either a Project or Group entity type'))
        end
      end
    end
  end
end
