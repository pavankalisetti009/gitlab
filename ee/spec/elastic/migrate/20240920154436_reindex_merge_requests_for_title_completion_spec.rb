# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240920154436_reindex_merge_requests_for_title_completion.rb')

RSpec.describe ReindexMergeRequestsForTitleCompletion, feature_category: :global_search do
  let(:version) { 20240920154436 }
  let(:migration) { described_class.new(version) }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '#migrate' do
    it 'creates reindexing task with correct target and options' do
      expect { migration.migrate }.to change { Elastic::ReindexingTask.count }.by(1)
      task = Elastic::ReindexingTask.last
      expect(task.targets).to eq(%w[MergeRequest])
      expect(task.options).to eq('skip_pending_migrations_check' => true)
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to eq(true)
    end
  end

  describe '#space_required_bytes' do
    let(:helper) { ::Gitlab::Elastic::Helper.default }
    let(:space_required_bytes) { migration.space_required_bytes }

    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:index_size_bytes).with(index_name: MergeRequest.index_name).and_return(1_000)
    end

    it 'returns space required' do
      expect(space_required_bytes).to eq(3_000)
    end
  end
end
