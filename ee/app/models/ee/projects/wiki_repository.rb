# frozen_string_literal: true

module EE
  module Projects
    module WikiRepository
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate :create_wiki, :repository_storage, :wiki, to: :project
        delegate :repository, to: :wiki

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :wiki_repository_state)

        with_replicator ::Geo::ProjectWikiRepositoryReplicator

        has_one :wiki_repository_state,
          class_name: 'Geo::WikiRepositoryState',
          foreign_key: :project_wiki_repository_id,
          inverse_of: :project_wiki_repository,
          autosave: false

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
            replicables
          end
        end
        scope :with_verification_state, ->(state) {
          joins(:wiki_repository_state)
            .where(wiki_repository_states: { verification_state: verification_state_value(state) })
        }

        scope :project_id_in, ->(ids) { where(project_id: ids) }

        def verification_state_object
          wiki_repository_state
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        override :pluck_verifiable_ids_in_range
        def pluck_verifiable_ids_in_range(range)
          verifiables(range)
            .primary_key_in(range)
            .pluck_primary_key
        end

        # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
        # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
        #         node, restricted by primary key
        override :replicables_for_current_secondary
        def replicables_for_current_secondary(primary_key_in)
          node = ::Gitlab::Geo.current_node

          replicables = available_replicables
          replicables = replicables.primary_key_in(primary_key_in) if primary_key_in.present?

          replicables
            .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
        end

        # @return [ActiveRecord::Relation<LfsObject>] scope observing selective
        #         sync settings of the given node
        override :selective_sync_scope
        def selective_sync_scope(node, **params)
          return all unless node.selective_sync?

          replicables = params.fetch(:replicables, all)

          # The primary_key_in in replicables_for_current_secondary method is at
          # most a range of IDs with a maximum of 10_000 records between them.
          replicable_projects =
            if params.key?(:primary_key_in) && params[:primary_key_in].present?
              replicables.primary_key_in(params[:primary_key_in])
            else
              replicables
            end

          replicables_project_ids = replicable_projects.distinct.pluck(:project_id)

          selective_projects_ids  =
            ::Project.selective_sync_scope(node)
              .id_in(replicables_project_ids)
              .pluck_primary_key

          project_id_in(selective_projects_ids)
        end

        override :verification_state_model_key
        def verification_state_model_key
          :project_wiki_repository_id
        end

        override :verification_state_table_class
        def verification_state_table_class
          Geo::WikiRepositoryState
        end
      end

      # Geo checks this method in FrameworkRepositorySyncService to avoid
      # snapshotting repositories using object pools
      def pool_repository
        nil
      end

      def wiki_repository_state
        super || build_wiki_repository_state
      end
    end
  end
end
