# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateWarnModeApprovalAuditEventService
      AUDIT_EVENT = 'policy_warn_mode_merge_request_approval'

      def initialize(merge_request, user)
        @merge_request = merge_request
        @project = merge_request.project
        @user = user
      end

      def execute
        create_security_policy_bot! unless project.security_policy_bot

        overrides = ::Security::ScanResultPolicies::ApprovalSettingsOverrides.new(
          project: project,
          warn_mode_policies: applicable_warn_mode_policies,
          enforced_policies: enforced_policies
        ).all

        return if overrides.empty?

        ::AuditEvent.transaction do
          ::Gitlab::Audit::Auditor.audit(audit_context) do
            overrides.each do |override|
              case override.attribute
              when :prevent_approval_by_author
                push_author_approved_event(override.security_policies) if author_approved?
              when :prevent_approval_by_commit_author
                push_commit_author_approved_event(override.security_policies) if commit_author_approved?
              when :require_password_to_approve
                push_password_required_event(override.security_policies)
              end
            end
          end
        end
      end

      private

      attr_reader :merge_request,
        :project,
        :user

      def push_author_approved_event(policies)
        push_audit_events(policies, "The merge request author approved their own merge request")
      end

      def push_commit_author_approved_event(policies)
        push_audit_events(policies, "A user approved a merge request that they also committed to")
      end

      def push_password_required_event(policies)
        push_audit_events(policies, "A user approved a merge request without reauthenticating")
      end

      def push_audit_events(policies, message)
        # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- false positive: Enumerable#pluck
        policy_names = policies.pluck(:name).join(", ")
        # rubocop:enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit

        connector = "which would have been prevented by the following security policies in warn mode:"

        merge_request.push_audit_event(
          "#{message}, #{connector} #{policy_names}",
          after_commit: false)
      end

      def author_approved?
        user == merge_request.author
      end

      def commit_author_approved?
        user.in?(merge_request.commits(load_from_gitaly: true).committers)
      end

      def audit_context
        {
          name: AUDIT_EVENT,
          target: merge_request,
          scope: project,
          author: project.security_policy_bot
        }
      end

      def create_security_policy_bot!
        Security::Orchestration::CreateBotService.new(project, nil, skip_authorization: true).execute.user
      end

      def applicable_warn_mode_policies
        project.approval_policies.select(&:warn_mode?)
      end

      def enforced_policies
        project.approval_policies.reject(&:warn_mode?)
      end
    end
  end
end
