# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class StartWorkflowService
      IMAGE = 'registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.4'

      def initialize(workflow:, params:)
        @project = workflow.project
        @workflow = workflow
        @current_user = workflow.user
        @params = params
      end

      def execute
        unless @current_user.can?(
          :execute_duo_workflow_in_ci, @workflow)
          return ServiceResponse.error(message: 'Can not execute workflow in CI',
            reason: :feature_unavailable)
        end

        service = ::Ci::Workloads::RunWorkloadService.new(
          project: @project,
          current_user: @current_user,
          source: :duo_workflow,
          workload: workload,
          create_branch: true
        )
        response = service.execute

        pipeline = response.payload
        if response.success?
          ServiceResponse.success(payload: {
            pipeline_id: pipeline.id,
            pipeline_path: Gitlab::Application.routes.url_helpers.project_pipeline_path(@project, pipeline)
          })
        else
          ServiceResponse.error(message: response.message, reason: :workload_failure)
        end
      end

      private

      def workload
        ::Ai::DuoWorkflows::Workload.new(@current_user, @params.merge!({ workflow_id: @workflow.id }))
      end
    end
  end
end
