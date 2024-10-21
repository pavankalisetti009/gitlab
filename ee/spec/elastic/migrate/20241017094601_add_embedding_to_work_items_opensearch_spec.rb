# frozen_string_literal: true

require 'spec_helper'
# require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20241017094601_add_embedding_to_work_items_opensearch.rb')

RSpec.describe AddEmbeddingToWorkItemsOpensearch, feature_category: :global_search do
  let(:version) { 20241017094601 }
  let(:migration) { described_class.new(version) }

  describe 'migration' do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    it 'does not have migration options set', :aggregate_failures do
      expect(migration).not_to be_batched
      expect(migration).not_to be_retry_on_failure
    end

    describe '#migrate' do
      it 'creates reindexing task with correct target and options' do
        expect { migration.migrate }.to change { Elastic::ReindexingTask.count }.by(1)
        task = Elastic::ReindexingTask.last
        expect(task.targets).to eq(%w[WorkItem])
        expect(task.options).to eq({ 'skip_pending_migrations_check' => true })
      end
    end

    describe '#completed?' do
      it 'always returns true' do
        expect(migration.completed?).to eq(true)
      end
    end
  end

  describe 'skip_migration?' do
    let(:helper) { Gitlab::Elastic::Helper.default }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:matching_distribution?).and_return(vectors_supported)
      described_class.skip_if -> { !Gitlab::Elastic::Helper.default.matching_distribution?(:opensearch) }
    end

    context 'if vectors are supported' do
      let(:vectors_supported) { true }

      it 'returns false' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'if vectors are not supported' do
      let(:vectors_supported) { false }

      it 'returns true' do
        expect(migration.skip_migration?).to be_truthy
      end
    end
  end
end
