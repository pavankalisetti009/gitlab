# frozen_string_literal: true

module EE
  module DependencyProxy
    module Manifest
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :dependency_proxy_manifest_state)

        with_replicator ::Geo::DependencyProxyManifestReplicator

        has_one :dependency_proxy_manifest_state,
          autosave: false,
          inverse_of: :dependency_proxy_manifest,
          class_name: 'Geo::DependencyProxyManifestState',
          foreign_key: :dependency_proxy_manifest_id

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
            replicables
          end
        end

        scope :with_verification_state, ->(state) do
          joins(:dependency_proxy_manifest_state)
            .where(dependency_proxy_manifest_states: { verification_state: verification_state_value(state) })
        end

        scope :group_id_in, ->(ids) { joins(:group).merge(::Namespace.id_in(ids)) }

        def verification_state_object
          dependency_proxy_manifest_state
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
        # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
        #         node, restricted by primary key
        override :replicables_for_current_secondary
        def replicables_for_current_secondary(primary_key_in)
          node = ::Gitlab::Geo.current_node

          replicables = available_replicables.merge(object_storage_scope(node))
          replicables = replicables.primary_key_in(primary_key_in) if primary_key_in.present?

          replicables
            .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
        end

        override :selective_sync_scope
        def selective_sync_scope(node, **params)
          return all unless node.selective_sync?

          replicables = group_id_in(node.namespaces_for_group_owned_replicables.select(:id))

          if params.key?(:primary_key_in) && params[:primary_key_in].present?
            replicables.primary_key_in(params[:primary_key_in])
          else
            replicables
          end
        end

        override :verification_state_table_class
        def verification_state_table_class
          Geo::DependencyProxyManifestState
        end
      end

      def dependency_proxy_manifest_state
        super || build_dependency_proxy_manifest_state
      end
    end
  end
end
