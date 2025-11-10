# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateWorkflowService
      include ::Services::ReturnServiceResponses
      include Concerns::WorkflowEventTracking

      def initialize(container:, current_user:, params:)
        @container = container || current_user.user_preference.get_default_duo_namespace
        @current_user = current_user
        # Remove ids to avoid confusion - @container determines the workflow scope, not raw IDs
        @params = params.except(:namespace_id, :project_id)
      end

      def execute
        unless @container.is_a?(::Project) || @container.is_a?(::Namespace)
          return error('container must be a Project or Namespace', :bad_request)
        end

        response = check_ai_catalog_item_access || check_access
        return response if response&.error?

        workflow = Ai::DuoWorkflows::Workflow.new(workflow_attributes)

        return error(workflow.errors.full_messages.join(', '), :bad_request) unless workflow.save

        track_workflow_event("agent_platform_session_created", workflow)

        success(workflow: workflow)
      end

      def workflow_attributes
        @params.merge(
          user: @current_user,
          **container_attributes
        )
      end

      private

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
        return if Ability.allowed?(@current_user, :access_duo_agentic_chat, @container)

        error('forbidden to access agentic chat', :forbidden)
      end

      def check_duo_workflow_access
        return if Ability.allowed?(@current_user, :duo_workflow, @container) && @container.is_a?(::Project)

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
    end
  end
end
