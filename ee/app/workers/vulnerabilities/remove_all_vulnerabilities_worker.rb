# frozen_string_literal: true

module Vulnerabilities
  class RemoveAllVulnerabilitiesWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    urgency :low
    data_consistency :delayed

    feature_category :vulnerability_management

    def perform(project_id)
      project = Project.find_by_id(project_id)

      return unless project

      Vulnerabilities::Removal::RemoveFromProjectService.new(project).execute
    end
  end
end
