# frozen_string_literal: true

module Geo
  class ProjectRepositoryReplicator < Gitlab::Geo::Replicator
    include ::Geo::RepositoryReplicatorStrategy

    def self.model
      ::Project
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Project Repository')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Project Repositories')
    end

    def self.geo_project_repository_replication_v2_enabled?
      ::Feature.enabled?(:geo_project_repository_replication_v2, :instance)
    end

    def before_housekeeping
      return unless ::Gitlab::Geo.secondary?

      create_object_pool_on_secondary if create_object_pool_on_secondary?
    end

    def repository
      model_record.repository
    end

    # Ensure that a Project related event is always published, but a
    # ProjectRepository event is only published when the FF is enabled.
    def should_publish_replication_event?
      return false unless super
      return true if model_record.is_a?(::Project)

      self.class.geo_project_repository_replication_v2_enabled? && model_record.is_a?(::ProjectRepository)
    end

    private

    def pool_repository
      model_record.pool_repository
    end

    def create_object_pool_on_secondary
      Geo::CreateObjectPoolService.new(pool_repository).execute
    end

    def create_object_pool_on_secondary?
      return unless model_record.object_pool_missing?
      return unless pool_repository.source_project_repository.exists?

      true
    end
  end
end
