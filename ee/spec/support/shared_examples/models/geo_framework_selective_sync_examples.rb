# frozen_string_literal: true

# Resusable examples for Geo SSF selective_sync_scope:
#
# - first_replicable_and_in_selective_sync: is the first replicable, there must be none with a lower ID. It is included
#                                           in selective sync by namespace, shards, or organizations.
# - second_replicable_and_in_selective_sync: has a greater ID than replicable_1. It is included in selective sync by
#                                            namespace, shards, or organizations.
# - last_replicable_and_not_in_selective_sync: is the last replicable, there must be none with a higher ID. It is not
#                                              included in any kind of selective sync.
#
RSpec.shared_examples 'Geo framework selective sync scenarios' do |method_name|
  let(:primary_key) { described_class.primary_key }
  let(:start_id) { described_class.minimum(primary_key) }
  let(:end_id) { described_class.maximum(primary_key) }

  context 'with selective sync by namespace' do
    before do
      secondary.update!(selective_sync_type: 'namespaces', namespaces: [group_1])
    end

    it 'returns replicables that belong to the namespaces' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          first_replicable_and_in_selective_sync,
          second_replicable_and_in_selective_sync
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          second_replicable_and_in_selective_sync
        ])
    end
  end

  context 'with selective sync by shard' do
    before do
      secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['default'])
    end

    it 'returns replicables that belong to the shards' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          first_replicable_and_in_selective_sync,
          second_replicable_and_in_selective_sync
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          second_replicable_and_in_selective_sync
        ])
    end
  end

  context 'with selective sync by organizations' do
    before do
      secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])
    end

    it 'returns replicables that belong to the organizations' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          first_replicable_and_in_selective_sync,
          second_replicable_and_in_selective_sync
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          second_replicable_and_in_selective_sync
        ])
    end
  end

  context 'with selective sync disabled' do
    it 'returns all replicables' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          first_replicable_and_in_selective_sync,
          second_replicable_and_in_selective_sync,
          last_replicable_and_not_in_selective_sync
        ])
    end
  end

  def find_replicables(method_name, primary_key_in)
    if method_name != :selective_sync_scope
      described_class.public_send(method_name, primary_key_in)
    else
      described_class.public_send(method_name, secondary, primary_key_in: primary_key_in)
    end
  end
end
