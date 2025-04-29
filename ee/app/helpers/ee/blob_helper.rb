# frozen_string_literal: true

module EE
  module BlobHelper
    extend ::Gitlab::Utils::Override

    override :vue_blob_header_app_data
    def vue_blob_header_app_data(project, blob, ref)
      super.merge({
        new_workspace_path: new_remote_development_workspace_path
      })
    end

    override :vue_blob_app_data
    def show_duo_workflow_action?(blob)
      return false unless ::Feature.enabled?(:duo_workflow_in_ci, blob.project)

      ::Gitlab::FileDetector.type_of(blob.name) == :jenkinsfile && current_user.present? && ::Ai::DuoWorkflow.enabled?
    end

    def vue_blob_app_data(project, blob, ref)
      super.merge({
        explain_code_available: ::Gitlab::Llm::TanukiBot.enabled_for?(user: current_user, container: project).to_s,
        new_workspace_path: new_remote_development_workspace_path,
        show_duo_workflow_action: show_duo_workflow_action?(blob).to_s,
        duo_workflow_invoke_path: api_v4_ai_duo_workflows_workflows_path
      })
    end
  end
end
