# frozen_string_literal: true

module EE
  module Import
    module SourceUsers
      module ReassignService
        extend ::Gitlab::Utils::Override

        private

        override :run_validations
        def run_validations
          validation_error = super

          return validation_error if validation_error

          error_invalid_assignee_due_to_sso_enforcement unless valid_assignee_if_sso_enforcement_is_applicable?
        end

        def valid_assignee_if_sso_enforcement_is_applicable?
          ::Gitlab::Auth::GroupSaml::MembershipEnforcer.new(root_namespace).can_add_user?(assignee_user)
        end

        def error_invalid_assignee_due_to_sso_enforcement
          ServiceResponse.error(
            message: invalid_assignee_due_to_sso_enforcement_message,
            reason: :invalid_assignee,
            payload: import_source_user
          )
        end

        def invalid_assignee_due_to_sso_enforcement_message
          s_('UserMapping|You can assign only users with linked SAML and SCIM identities. ' \
            'Ensure the user has signed into GitLab through your SAML SSO provider and has an ' \
            'active SCIM identity for this group.')
        end
      end
    end
  end
end
