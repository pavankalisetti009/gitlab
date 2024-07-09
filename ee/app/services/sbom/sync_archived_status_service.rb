# frozen_string_literal: true

module Sbom
  class SyncArchivedStatusService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::ExclusiveLeaseHelpers

    BATCH_SIZE = 100
    LEASE_TTL = 1.hour

    def initialize(project_id)
      @project_id = project_id
    end

    def execute
      return unless project

      in_lock(lease_key, ttl: LEASE_TTL) { update_archived_status }
    end

    private

    attr_reader :project_id

    def update_archived_status
      project.sbom_occurrences.each_batch(of: BATCH_SIZE) do |batch|
        batch.update_all(archived: project.archived)
      end
    end

    def project
      Project.find_by_id(project_id)
    end
    strong_memoize_attr :project

    def lease_key
      Sbom::Ingestion.project_lease_key(project_id)
    end
  end
end
