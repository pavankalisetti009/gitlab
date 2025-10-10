# frozen_string_literal: true

RSpec.shared_examples 'Geo framework selective sync scenarios' do |method_name|
  let(:start_id) { described_class.minimum(:id) }
  let(:end_id) { described_class.maximum(:id) }

  context 'with selective sync by namespace' do
    before do
      secondary.update!(selective_sync_type: 'namespaces', namespaces: [group_1])
    end

    it 'returns replicables that belong to the namespaces' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          replicable_1,
          replicable_2
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          replicable_2
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
          replicable_1,
          replicable_2
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          replicable_2
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
          replicable_1,
          replicable_2
        ])
    end

    it 'excludes replicables outside the primary key ID range' do
      replicables = find_replicables(method_name, (start_id + 1)..end_id)

      expect(replicables)
        .to match_array([
          replicable_2
        ])
    end
  end

  context 'with selective sync disabled' do
    it 'returns all replicables' do
      replicables = find_replicables(method_name, start_id..end_id)

      expect(replicables)
        .to match_array([
          replicable_1,
          replicable_2,
          replicable_3
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
