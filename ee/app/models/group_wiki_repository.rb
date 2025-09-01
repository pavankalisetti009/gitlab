# frozen_string_literal: true

class GroupWikiRepository < ApplicationRecord
  extend ::Gitlab::Utils::Override
  include ::Geo::ReplicableModel
  include ::Geo::VerifiableModel
  include EachBatch
  include Shardable

  with_replicator Geo::GroupWikiRepositoryReplicator

  belongs_to :group

  has_one :group_wiki_repository_state,
    class_name: 'Geo::GroupWikiRepositoryState',
    inverse_of: :group_wiki_repository,
    autosave: false

  validates :group, :disk_path, presence: true, uniqueness: true

  delegate :create_wiki, :repository_storage, to: :group
  delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :group_wiki_repository_state)

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
    joins(:group_wiki_repository_state)
      .where(group_wiki_repository_states: { verification_state: verification_state_value(state) })
  }

  # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
  # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
  #         node, restricted by primary key
  override :replicables_for_current_secondary
  def self.replicables_for_current_secondary(primary_key_in)
    node = ::Gitlab::Geo.current_node

    replicables =
      available_replicables
        .primary_key_in(primary_key_in)

    replicables
      .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
  end

  # @return [ActiveRecord::Relation<GroupWikiRepository>] scope observing selective sync
  #          settings of the given node
  override :selective_sync_scope
  def self.selective_sync_scope(node, **params)
    return all unless node.selective_sync?

    replicables =
      if node.selective_sync_by_namespaces? || node.selective_sync_by_organizations?
        group_wiki_repositories_for_selected_namespaces(node)
      elsif node.selective_sync_by_shards?
        group_wiki_repositories_for_selected_shards(node)
      end

    if params.key?(:primary_key_in) && params[:primary_key_in].present?
      replicables.primary_key_in(params[:primary_key_in])
    else
      replicables
    end
  end

  def self.group_wiki_repositories_for_selected_namespaces(node)
    joins(:group).where(group_id: node.namespaces_for_group_owned_replicables.select(:id))
  end

  def self.group_wiki_repositories_for_selected_shards(node)
    for_repository_storage(node.selective_sync_shards)
  end

  override :verification_state_table_class
  def self.verification_state_table_class
    ::Geo::GroupWikiRepositoryState
  end

  override :verification_state_model_key
  def self.verification_state_model_key
    :group_wiki_repository_id
  end

  def group_wiki_repository_state
    super || build_group_wiki_repository_state
  end

  # Geo checks this method in FrameworkRepositorySyncService to avoid
  # snapshotting repositories using object pools
  def pool_repository
    nil
  end

  def repository
    group.wiki.repository
  end

  def verification_state_object
    group_wiki_repository_state
  end
end
