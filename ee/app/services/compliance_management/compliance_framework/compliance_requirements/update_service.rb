# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ComplianceRequirements
      class UpdateService < BaseRequirementsService
        def execute
          return ServiceResponse.error(message: _('Not permitted to update requirement')) unless permitted?
          return control_limit_error if control_count_exceeded?

          begin
            ComplianceManagement::ComplianceFramework::ComplianceRequirement.transaction do
              requirement.update!(params)

              update_controls
            end
          rescue ActiveRecord::RecordInvalid
            return error
          rescue InvalidControlError => e
            return ServiceResponse.error(message: e.message, payload: e.message)
          end

          audit_changes

          success
        end

        private

        def permitted?
          can? current_user, :admin_compliance_framework, requirement.framework
        end

        def audit_changes
          requirement.previous_changes.each do |attribute, changes|
            next if attribute.eql?('updated_at')

            audit_context = {
              name: 'update_compliance_requirement',
              author: current_user,
              scope: requirement.framework.namespace,
              target: requirement,
              message: "Changed compliance requirement's #{attribute} from #{changes[0]} to #{changes[1]}"
            }

            ::Gitlab::Audit::Auditor.audit(audit_context)
          end
        end

        def error
          ServiceResponse.error(message: _('Failed to update compliance requirement'), payload: requirement.errors)
        end

        def update_controls
          return if controls.nil?

          requirement.delete_compliance_requirements_controls
          add_controls
        end
      end
    end
  end
end
