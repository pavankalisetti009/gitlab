# frozen_string_literal: true

module EE
  # ProjectRepository EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `ProjectRepository` model
  module ProjectRepository # rubocop:disable Gitlab/BoundedContexts -- EE module for existing model
    extend ActiveSupport::Concern

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel

      with_replicator Geo::ProjectRepositoryReplicator

      has_one :project_repository_state,
        autosave: false,
        inverse_of: :project_repository,
        foreign_key: :project_repository_id,
        class_name: 'Geo::ProjectRepositoryState'

      # Delegate repository-related methods to the associated project
      delegate(
        :repository,
        :repository_storage,
        to: :project)

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS,
        to: :project_repository_state)

      # On primary, `verifiables` are records that can be checksummed and/or are replicable.
      # On secondary, `verifiables` are records that have already been replicated
      # and (ideally) have been checksummed on the primary
      scope :verifiables, ->(primary_key_in = nil) do
        node = ::GeoNode.current_node

        replicables =
          available_replicables

        if ::Gitlab::Geo.org_mover_extend_selective_sync_to_primary_checksumming?
          replicables.merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
        else
          primary_key_in ? replicables.primary_key_in(primary_key_in) : replicables
        end
      end

      scope :with_verification_state, ->(state) do
        joins(:project_repository_state)
          .where(project_repository_states: {
            verification_state: verification_state_value(state)
          })
      end

      def verification_state_object
        project_repository_state
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :pluck_verifiable_ids_in_range
      def pluck_verifiable_ids_in_range(range)
        verifiables(range).pluck_primary_key
      end

      # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
      # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
      #         node, restricted by primary key
      override :replicables_for_current_secondary
      def replicables_for_current_secondary(primary_key_in)
        node = ::Gitlab::Geo.current_node

        replicables = available_replicables

        replicables
          .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
      end

      # @return [ActiveRecord::Relation<ProjectRepository>] scope observing selective sync
      #         settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        replicables = params.fetch(:replicables, all)
        replicables = replicables.primary_key_in(params[:primary_key_in]) if params[:primary_key_in].presence

        return replicables unless node.selective_sync?

        selective_projects_ids = ::Project.selective_sync_scope(node, primary_key_in: nil)

        replicables.where(project_id: selective_projects_ids)
      end

      override :verification_state_table_class
      def verification_state_table_class
        ::Geo::ProjectRepositoryState
      end

      override :verification_state_model_key
      def verification_state_model_key
        :project_repository_id
      end
    end

    def project_repository_state
      super || build_project_repository_state
    end
  end # rubocop:enable Gitlab/BoundedContexts
end
