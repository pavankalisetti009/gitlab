# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateWorkflowService
      include ::Services::ReturnServiceResponses
      include Concerns::WorkflowEventTracking

      def initialize(container:, current_user:, params:)
        @container = container || current_user.user_preference.duo_default_namespace_with_fallback
        @current_user = current_user
        # Remove ids to avoid confusion - @container determines the workflow scope, not raw IDs
        @params = params.except(:namespace_id, :project_id)
        @params[:agent_privileges] ||= ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
      end

      def execute
        unless @container.is_a?(::Project) || @container.is_a?(::Namespace)
          return error('container must be a Project or Namespace', :bad_request)
        end

        namespace = @container.is_a?(::Project) ? @container.namespace : @container
        credit_check_response = Ai::UsageQuotaService.new(
          ai_feature: chat? ? :duo_chat : :duo_agent_platform, user: @current_user, namespace: namespace
        ).execute

        if credit_check_response.error?
          # http status should not be part of Service, but needs significant refactoring in the callers of
          # CreateWorkflowService.execute
          http_status = http_status_for_quota_error(credit_check_response.reason)
          return error(credit_check_response.message, http_status, pass_back: { reason: credit_check_response.reason })
        end

        response = check_ai_catalog_item_access || check_access
        return response if response&.error?

        workflow = Ai::DuoWorkflows::Workflow.new(workflow_attributes)

        return error(workflow.errors.full_messages.join(', '), :bad_request) unless workflow.save

        track_workflow_event("agent_platform_session_created", workflow)

        audit_context = {
          name: 'duo_session_created',
          author: @current_user,
          scope: workflow.project || workflow.namespace,
          target: workflow,
          target_details: "#{workflow.workflow_definition} session #{workflow.id}",
          message: 'Created Duo session'
        }
        begin
          ::Gitlab::Audit::Auditor.audit(audit_context)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e, workflow_id: workflow.id)
        end

        create_workflow_system_note(workflow)

        success(workflow: workflow)
      end

      def workflow_attributes
        base_params.merge(
          user: @current_user,
          **container_attributes,
          **noteable_attributes,
          **service_account_attributes
        )
      end

      private

      def base_params
        @params.except(:issue_id, :merge_request_id, :service_account)
      end

      def service_account_attributes
        return {} unless @params[:service_account]

        { service_account: @params[:service_account] }
      end

      def create_workflow_system_note(workflow)
        noteable = workflow.issue
        return unless noteable
        return unless noteable.respond_to?(:project) && noteable.project.present?

        # Who/what initiated the workflow
        # currently the user, but could be another agent
        # in future iterations
        trigger_source = @current_user

        SystemNoteService.agent_session_started(
          noteable,
          noteable.project,
          workflow.id,
          trigger_source
        )
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(
          err,
          workflow_id: workflow.id,
          noteable_type: noteable.class.name,
          noteable_id: noteable.id
        )
      end

      def check_ai_catalog_item_access
        return unless @params[:ai_catalog_item_version]

        finder_params = {
          item_id: @params[:ai_catalog_item_version].ai_catalog_item_id
        }

        if @container.is_a?(::Project)
          finder_params[:project_id] = @container.id
        elsif @container.is_a?(::Namespace)
          finder_params[:group_id] = @container.id
        end

        return if Ai::Catalog::ItemConsumersFinder.new(@current_user, params: finder_params).execute.exists?

        error('ItemVersion not found', :not_found)
      end

      def check_access
        if chat?
          check_agentic_chat_access
        else
          check_duo_workflow_access
        end
      end

      def check_agentic_chat_access
        unless Ability.allowed?(@current_user, :access_duo_agentic_chat, @container)
          return error('forbidden to access agentic chat', :forbidden)
        end

        reference = FoundationalChatAgent.reference_from_workflow_definition(workflow_definition)
        return if foundational_agents_settings_container.foundational_agent_enabled?(reference)

        error('foundation agent disabled for namespace', :forbidden)
      end

      def check_duo_workflow_access
        return if Ability.allowed?(@current_user, :create_duo_workflow_for_ci, @container)

        error('forbidden to access duo workflow', :forbidden)
      end

      def workflow_definition
        @params['workflow_definition'] || @params[:workflow_definition]
      end

      def chat?
        FoundationalChatAgent.foundational_workflow_definition?(workflow_definition)
      end

      def container_attributes
        if @container.is_a?(::Project)
          { project: @container }
        elsif @container.is_a?(::Namespace)
          { namespace: @container }
        end
      end

      def noteable_attributes
        attributes = {}

        if @params[:issue_id].present?
          work_item = find_issue(@params[:issue_id])
          attributes[:issue_id] = work_item.id if work_item
        end

        attributes
      end

      def find_issue(issue_iid)
        return unless @container.is_a?(::Project)

        IssuesFinder.new(@current_user, project_id: @container.id, iids: [issue_iid]).execute.first
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, issue_iid: issue_iid, container_id: @container.id)
        nil
      end

      def http_status_for_quota_error(reason)
        case reason
        when :user_missing, :namespace_missing
          :bad_request
        when :usage_quota_exceeded
          :payment_required
        else
          :internal_server_error
        end
      end

      def foundational_agents_settings_container
        unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          return ::Organizations::Organization.default_organization
        end

        # use_billable_namespace
        # once https://gitlab.com/gitlab-org/gitlab/-/issues/580901 is implemented,
        # this should be moved to the source of truth
        @current_user.user_preference.duo_default_namespace_with_fallback ||
          (@container.is_a?(::Project) ? @container.parent : @container).root_ancestor
      end
    end
  end
end
