# frozen_string_literal: true

module EE
  module Packages
    module PackageFile
      extend ActiveSupport::Concern

      EE_SEARCHABLE_ATTRIBUTES = %i[file_name].freeze

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel
        include ::Geo::VerificationStateDefinition
        include ::Gitlab::SQL::Pattern

        with_replicator ::Geo::PackageFileReplicator

        has_one :package_file_state,
          autosave: false,
          inverse_of: :package_file,
          foreign_key: :package_file_id,
          class_name: '::Geo::PackageFileState'

        # On primary, `verifiables` are records that can be checksummed and/or are replicable.
        # On secondary, `verifiables` are records that have already been replicated
        # and (ideally) have been checksummed on the primary
        scope :verifiables, ->(primary_key_in = nil) do
          node = ::GeoNode.current_node

          replicables =
            available_replicables
              .merge(object_storage_scope(node))

          if ::Gitlab::Geo.org_mover_extend_selective_sync_to_primary_checksumming?
            replicables.merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
          else
            replicables = replicables.primary_key_in(primary_key_in) if primary_key_in
            replicables
          end
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # Search for a list of package_files based on the query given in `query`.
        #
        # @param [String] query term that will search over package_file :file_name
        #
        # @return [ActiveRecord::Relation<Packages::PackageFile>] a collection of package files
        def search(query)
          return all if query.empty?

          fuzzy_search(query, EE_SEARCHABLE_ATTRIBUTES).limit(500)
        end

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

          replicables = available_replicables.merge(object_storage_scope(node))

          replicables
            .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
        end

        override :selective_sync_scope
        def selective_sync_scope(node, **params)
          replicables = params.fetch(:replicables, all)
          replicables = replicables.primary_key_in(params[:primary_key_in]) if params[:primary_key_in].presence

          return replicables unless node.selective_sync?

          replicables
            .joins(:package)
            .where(packages_packages: { project_id: ::Project.selective_sync_scope(node).select(:id) })
        end
      end
    end
  end
end
