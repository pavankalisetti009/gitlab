# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240410193847_add_embedding_to_issues.rb')

RSpec.describe AddEmbeddingToIssues, feature_category: :global_search do
  let(:version) { 20240410193847 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    allow(migration).to receive(:helper).and_return(helper)
  end

  describe 'migration', :elastic, :sidekiq_inline do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    describe '.migrate' do
      describe 'migration process' do
        before do
          allow(helper).to receive(:get_mapping).and_return({})
        end

        it 'updates the issues index mappings' do
          expect(helper).to receive(:update_mapping)

          migration.migrate
        end
      end
    end

    describe '.completed?' do
      context 'when mapping has not been updated' do
        before do
          allow(helper).to receive(:get_mapping).and_return({})
        end

        specify { expect(migration).not_to be_completed }
      end
    end
  end

  describe 'skip_migration?' do
    before do
      allow(helper).to receive(:vectors_supported?).and_return(vectors_supported)
      described_class.skip_if -> { !Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch) }
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
