# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ComplianceRequirements
      class CreateService < BaseService
        InvalidControlError = Class.new(StandardError)

        def initialize(framework:, params:, current_user:, controls: [])
          @framework = framework
          @params = params
          @current_user = current_user
          @requirement = ComplianceManagement::ComplianceFramework::ComplianceRequirement.new
          @controls = controls
        end

        def execute
          return ServiceResponse.error(message: _('Not permitted to create requirement')) unless permitted?
          return control_limit_error if control_count_exceeded?

          begin
            ComplianceManagement::ComplianceFramework::ComplianceRequirement.transaction do
              create_requirement

              add_controls
            end
          rescue ActiveRecord::RecordInvalid
            return error
          rescue InvalidControlError => e
            return ServiceResponse.error(message: e.message, payload: e.message)
          end

          audit_create

          success
        end

        private

        attr_reader :params, :current_user, :framework, :requirement, :controls

        def control_limit_error
          ServiceResponse.error(
            message: format(_('More than %{control_count} controls not allowed for a requirement.'),
              control_count: ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl::
                MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT
            )
          )
        end

        def control_count_exceeded?
          controls.length > ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl::
              MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT
        end

        def permitted?
          can? current_user, :admin_compliance_framework, framework
        end

        def create_requirement
          assign_requirement_attributes
          requirement.save!
        end

        def assign_requirement_attributes
          requirement.assign_attributes(
            framework: framework,
            namespace_id: framework.namespace.id,
            name: params[:name],
            description: params[:description]
          )
        end

        def success
          ServiceResponse.success(payload: { requirement: requirement })
        end

        def audit_create
          audit_context = {
            name: 'created_compliance_requirement',
            author: current_user,
            scope: framework.namespace,
            target: requirement,
            message: "Created compliance requirement #{requirement.name} for framework #{framework.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def error
          ServiceResponse.error(message: _('Failed to create compliance requirement'), payload: requirement.errors)
        end

        def add_controls
          control_objects = []

          controls.each do |control_params|
            control_object = build_control(control_params)
            validate_control!(control_object)

            control_objects << control_object
          rescue ArgumentError, ActiveRecord::RecordInvalid => e
            raise InvalidControlError, invalid_control_response(control_params[:name], e.message)
          end

          persist_controls!(control_objects)
        rescue ActiveRecord::RecordNotUnique
          raise InvalidControlError, _("Duplicate entries found for compliance controls for the requirement.")
        end

        def build_control(control_params)
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.new(
            compliance_requirement: requirement,
            namespace_id: requirement.namespace_id,
            name: control_params[:name],
            expression: control_params[:expression],
            control_type: control_params[:control_type] || 'internal',
            secret_token: control_params[:secret_token],
            external_url: control_params[:external_url]
          )
        end

        def validate_control!(control)
          control.validate!
        end

        def persist_controls!(control_objects)
          return if control_objects.empty?

          control_attributes = control_objects.map do |obj|
            obj.attributes.except('secret_token', 'id', 'created_at', 'updated_at')
          end

          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.insert_all!(control_attributes)
        end

        def invalid_control_response(control_name, error_message)
          format(_("Failed to add compliance requirement control %{control_name}: %{error_message}"),
            control_name: control_name, error_message: error_message
          )
        end
      end
    end
  end
end
