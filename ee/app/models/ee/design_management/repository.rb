# frozen_string_literal: true

module EE
  module DesignManagement
    module Repository
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :design_management_repository_state)

        with_replicator Geo::DesignManagementRepositoryReplicator

        has_one :design_management_repository_state,
          autosave: false,
          inverse_of: :design_management_repository,
          class_name: 'Geo::DesignManagementRepositoryState',
          foreign_key: 'design_management_repository_id'

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
          joins(:design_management_repository_state)
            .where(design_management_repository_states: { verification_state: verification_state_value(state) })
        }

        scope :project_id_in, ->(ids) { where(project_id: ids) }
      end

      def verification_state_object
        design_management_repository_state
      end

      class_methods do
        extend ::Gitlab::Utils::Override

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

        override :verification_state_table_class
        def verification_state_table_class
          Geo::DesignManagementRepositoryState
        end
      end

      # Geo checks this method in FrameworkRepositorySyncService to avoid
      # snapshotting repositories using object pools
      def pool_repository
        nil
      end

      def design_management_repository_state
        super || build_design_management_repository_state
      end
    end
  end
end
