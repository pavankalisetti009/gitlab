# frozen_string_literal: true

# Shared examples for testing Geo framework selective sync behavior.
#
# This shared example tests three methods that filter replicables based on selective sync configuration:
# - replicables_for_current_secondary: Returns replicables that should be synced to a secondary node
# - selective_sync_scope: Filters replicables based on the node's selective sync settings
# - verifiables: Returns replicables that can be checksummed/verified
#
# The examples test all selective sync types: namespaces, shards, and organizations.
# They also verify that primary key ranges and object storage settings are respected.
#
# Required test fixtures (let_it_be):
#
# - first_replicable_and_in_selective_sync
#   The replicable with the lowest ID. Must be included in all selective sync scopes
#   (namespace, shard, and organization).
#
# - second_replicable_and_in_selective_sync
#   A replicable with a higher ID than the first. Must be included in all selective sync scopes.
#   Used to verify that multiple replicables are returned and primary key ranges work correctly.
#
# - third_replicable_and_on_object_storage_and_in_selective_sync
#   A replicable stored in object storage. Only required for replicable types that support
#   object storage (blob types). Must be included in namespace and organization selective sync scopes.
#   Used to verify that object storage filtering works correctly.
#
# - last_replicable_and_not_in_selective_sync
#   The replicable with the highest ID. Must NOT be included in any selective sync scope.
#   Used to verify that selective sync properly excludes out-of-scope replicables.
#
# Usage:
#   include_examples 'Geo Framework selective sync behavior'
RSpec.shared_examples 'Geo Framework selective sync behavior' do
  let_it_be_with_refind(:secondary) { create(:geo_node, :secondary) }

  let(:primary_key) { described_class.primary_key }
  let(:start_id) { described_class.minimum(primary_key) }
  let(:end_id) { described_class.maximum(primary_key) }

  before do
    stub_current_geo_node(secondary)
    secondary.update!(sync_object_storage: false)
  end

  shared_examples 'selective sync scope tests' do |sync_type, setup_block|
    before do
      instance_exec(&setup_block)
    end

    it "returns replicables that belong to the #{sync_type}" do
      replicables = find_replicables_to_sync

      expect(replicables).to match_array(expected_replicables_to_sync)
    end

    it "includes replicables inside the primary key ID range that belong to the #{sync_type}" do
      replicables = find_replicables_to_sync(start_id..end_id)

      expect(replicables).to match_array(expected_replicables_to_sync)
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables_to_sync((start_id + 1)..end_id)

      expect(replicables).to match_array(expected_replicables_to_sync(exclude_first: true))
    end

    context 'with object storage sync enabled' do
      before do
        skip_unless_object_storable
        secondary.update!(sync_object_storage: true)
      end

      it "returns replicables stored in object storage that belong to the #{sync_type}" do
        replicables = find_replicables_to_sync(start_id..end_id)

        expect(replicables).to match_array(expected_replicables_to_sync)
      end
    end
  end

  shared_examples 'selective sync scopes' do |method_name|
    let(:method_name) { method_name }

    context 'with selective sync by namespace' do
      include_examples 'selective sync scope tests', :namespaces, -> {
        secondary.update!(selective_sync_type: 'namespaces', namespaces: [group_1])
      }
    end

    context 'with selective sync by organizations' do
      include_examples 'selective sync scope tests', :organizations, -> {
        secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])
      }
    end

    context 'with selective sync by shard' do
      before do
        skip_if_blob_replicator
      end

      include_examples 'selective sync scope tests', :shards, -> {
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['default'])
      }
    end

    context 'with selective sync disabled' do
      it 'returns all replicables' do
        replicables = find_replicables_to_sync

        expect(replicables).to match_array(expected_replicables_to_sync(include_all: true))
      end

      it "returns all replicables inside the primary key ID range" do
        replicables = find_replicables_to_sync(start_id..end_id)

        expect(replicables).to match_array(expected_replicables_to_sync(include_all: true))
      end

      context 'with object storage sync enabled' do
        before do
          skip_unless_object_storable
          secondary.update!(sync_object_storage: true)
        end

        it 'returns all replicables including those stored in object storage' do
          replicables = find_replicables_to_sync(start_id..end_id)

          expect(replicables).to match_array(expected_replicables_to_sync(include_all: true))
        end
      end
    end
  end

  describe '.replicables_for_current_secondary' do
    include_examples 'selective sync scopes', :replicables_for_current_secondary
  end

  describe '.selective_sync_scope' do
    include_examples 'selective sync scopes', :selective_sync_scope

    it 'raises if an unrecognised selective sync type is used' do
      secondary.update_attribute(:selective_sync_type, 'unknown')

      expect { described_class.selective_sync_scope(secondary) }
        .to raise_error(Geo::Errors::UnknownSelectiveSyncType)
    end
  end

  describe '.verifiables' do
    include_examples 'selective sync scopes', :verifiables

    context 'with org_mover_extend_selective_sync_to_primary_checksumming feature flag' do
      context 'when enabled' do
        before do
          stub_feature_flags(org_mover_extend_selective_sync_to_primary_checksumming: true)
        end

        it 'applies selective sync scope' do
          secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])

          verifiables = described_class.verifiables

          expect(verifiables).to include(first_replicable_and_in_selective_sync)
          expect(verifiables).not_to include(last_replicable_and_not_in_selective_sync)
        end
      end

      context 'when disabled' do
        before do
          stub_feature_flags(org_mover_extend_selective_sync_to_primary_checksumming: false)
        end

        it 'does not apply selective sync scope' do
          secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])

          verifiables = described_class.verifiables

          expect(verifiables).to include(first_replicable_and_in_selective_sync)
          expect(verifiables).to include(last_replicable_and_not_in_selective_sync)
        end
      end
    end
  end

  private

  def skip_unless_object_storable
    return if object_storable?

    skip "Skipping because the #{described_class} does not store data in object storage"
  end

  def skip_if_blob_replicator
    return unless blob_replicator?

    skip "Skipping because the #{described_class} does not store data in shards"
  end

  def blob_replicator?
    described_class.replicator_class.data_type == 'blob'
  end

  def object_storable?
    described_class.object_storable?
  end

  def find_replicables_to_sync(primary_key_in = nil)
    if method_name != :selective_sync_scope
      described_class.public_send(method_name, primary_key_in)
    else
      described_class.public_send(method_name, secondary, primary_key_in: primary_key_in)
    end
  end

  def expected_replicables_to_sync(include_all: false, exclude_first: false)
    replicables = []
    replicables << first_replicable_and_in_selective_sync unless exclude_first
    replicables << second_replicable_and_in_selective_sync
    replicables << third_replicable_on_object_storage_and_in_selective_sync if should_include_object_storage_replicable?
    replicables << last_replicable_and_not_in_selective_sync if include_all
    replicables
  end

  def should_include_object_storage_replicable?
    return false unless object_storable?
    return true if method_name == :selective_sync_scope # selective_sync_scope doesn't apply object_storage_scope

    secondary.sync_object_storage?
  end
end
