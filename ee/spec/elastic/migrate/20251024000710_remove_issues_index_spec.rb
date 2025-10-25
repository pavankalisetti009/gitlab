# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251024000710_remove_issues_index.rb')

RSpec.describe RemoveIssuesIndex, :elastic_helpers, feature_category: :global_search do
  let(:version) { 20251024000710 }
  let(:helper) { Gitlab::Elastic::Helper.new }
  let(:index_name) { described_class::ISSUES_INDEX_NAME }

  subject(:migration) { described_class.new(version) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(migration).to receive(:helper).and_return(helper)
    set_elasticsearch_migration_to(version, including: false)
  end

  describe '#migrate' do
    context 'when index exists' do
      before do
        allow(helper).to receive(:index_exists?).with(index_name: index_name).and_return(true)
      end

      it 'removes the issues index' do
        expect(helper).to receive(:delete_index).with(index_name: index_name)
        migration.migrate
      end
    end

    context 'when index does not exist' do
      before do
        allow(helper).to receive(:index_exists?).with(index_name: index_name).and_return(false)
      end

      it 'does not attempt to delete the index' do
        expect(helper).not_to receive(:delete_index)
        migration.migrate
      end
    end
  end

  describe '#completed?' do
    it 'returns true when index does not exist' do
      expect(helper).to receive(:index_exists?).with(index_name: index_name).and_return(false)
      expect(migration.completed?).to be(true)
    end

    it 'returns false when index still exists' do
      expect(helper).to receive(:index_exists?).with(index_name: index_name).and_return(true)
      expect(migration.completed?).to be(false)
    end
  end

  describe '#retry_on_failure?' do
    it 'is true' do
      expect(migration.retry_on_failure?).to be(true)
    end
  end
end
