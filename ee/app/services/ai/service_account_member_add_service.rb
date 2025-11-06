# frozen_string_literal: true

module Ai
  class ServiceAccountMemberAddService
    def initialize(project, service_account_user)
      @project = project
      @service_account_user = service_account_user
    end

    def execute
      existing_member = project.member(service_account_user)
      return ServiceResponse.success(message: "Membership already exists. Nothing to do.") if existing_member

      return ServiceResponse.error(message: "Service account user not found") unless service_account_user

      # We must sync project_authorizations immediately to the service_account_user here because the next
      # steps in StartWorkflowService are immediately going to trigger permission checks and Gitaly callbacks on
      # behalf of the service account which check they have permissions to create a branch in this project.
      result = project.add_member(service_account_user, :developer, immediately_sync_authorizations: true)

      if result && result.persisted?
        ServiceResponse.success(payload: result)
      else
        ServiceResponse.error(message: "Failed to add service account as developer")
      end
    end

    private

    attr_reader :project, :service_account_user
  end
end
