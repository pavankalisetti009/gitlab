# frozen_string_literal: true

module EE
  module MemberUserEntity
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      unexpose :gitlab_employee
      expose :oncall_schedules, with: ::IncidentManagement::OncallScheduleEntity
      expose :escalation_policies, with: ::IncidentManagement::EscalationPolicyEntity

      expose :email, if: ->(user, options) do
        options[:current_user]&.can_admin_all_resources? ||
          user.managed_by_user?(options[:current_user], group: options[:source]&.root_ancestor)
      end

      expose :is_service_account, if: ->(user, _options) { user&.service_account? } do |user|
        user&.service_account?
      end

      def oncall_schedules
        object.oncall_schedules.for_project(project_ids)
      end

      def escalation_policies
        object.escalation_policies.for_project(project_ids)
      end
    end

    private

    # options[:source] is required to scope oncall schedules or policies
    # It should be either a Group or Project
    def project_ids
      strong_memoize(:project_ids) do
        next [] unless options[:source].present?

        options[:source].is_a?(Group) ? options[:source].project_ids : [options[:source].id]
      end
    end
  end
end
