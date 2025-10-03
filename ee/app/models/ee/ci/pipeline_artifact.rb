# frozen_string_literal: true

module EE
  module Ci
    module PipelineArtifact
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel
        include ::Geo::VerificationStateDefinition
        include ::Geo::ReplicableCiArtifactable

        with_replicator ::Geo::PipelineArtifactReplicator

        has_one :pipeline_artifact_state,
          ->(artifact) { where(partition_id: artifact.partition_id) },
          class_name: 'Geo::PipelineArtifactState',
          partition_foreign_key: :partition_id,
          inverse_of: :pipeline_artifact,
          autosave: false
      end

      class_methods do
        # Search for a list of projects associated, based on the query given in `query`.
        #
        # @param [String] query term that will search over projects :path, :name and :description
        #
        # @return [ActiveRecord::Relation<Ci::PipelineArtifact>] a collection of pipeline artifacts
        def search(query)
          return all if query.empty?

          # This is divided into two separate queries, one for the CI and one for the main database
          where(project_id: ::Project.search(query).limit(1000).pluck_primary_key)
        end
      end
    end
  end
end
