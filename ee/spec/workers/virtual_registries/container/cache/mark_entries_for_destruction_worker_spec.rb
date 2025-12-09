# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Cache::MarkEntriesForDestructionWorker, feature_category: :virtual_registry do
  let(:upstream) { build_stubbed(:virtual_registries_container_upstream) }
  let(:worker) { described_class.new }

  subject { worker.perform(upstream.id) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [upstream.id] }
  end

  it 'has an until_executed deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    it { is_expected.to be_nil }
  end
end
