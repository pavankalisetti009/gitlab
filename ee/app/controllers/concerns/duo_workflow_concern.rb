# frozen_string_literal: true

module DuoWorkflowConcern
  extend ActiveSupport::Concern

  def duo_workflow_enabled?(project = nil, user = nil)
    project ||= self.project
    user ||= current_user
    return false unless project && user

    project.duo_remote_flows_enabled && ::Ai::DuoWorkflow.enabled?
  end
end
