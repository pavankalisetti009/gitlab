# frozen_string_literal: true

module EE
  module Members
    module Projects
      module CreatorService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        private

        override :can_create_new_member?
        def can_create_new_member?
          return false unless service_account_eligible_for_membership?

          super && current_user.can?(:invite_project_members, member.project)
        end

        def service_account_eligible_for_membership?
          return true unless member.user&.service_account?

          ::Members::ServiceAccounts::EligibilityChecker.new(
            target_project: member.project).eligible?(member.user)
        end
      end
    end
  end
end
