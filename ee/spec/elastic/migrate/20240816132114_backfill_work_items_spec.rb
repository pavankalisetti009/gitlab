# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240816132114_backfill_work_items.rb')

RSpec.describe BackfillWorkItems, feature_category: :global_search do
  let(:version) { 20240816132114 }

  describe 'migration', :elastic do
    it_behaves_like 'migration reindexes all data' do
      let(:objects) { create_list(:work_item, 3) }
      let(:factory_to_create_objects) { :work_item }
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 50_000 }
    end
  end

  describe '#space_required_bytes' do
    let(:helper) { ::Gitlab::Elastic::Helper.default }
    let(:migration) { described_class.new(version) }

    subject(:space_required_bytes) { migration.space_required_bytes }

    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    end

    it 'returns space required' do
      expect(helper).to receive(:index_size_bytes)
        .with(index_name: Issue.index_name).and_return(1000)
      expect(helper).to receive(:index_size_bytes)
        .with(index_name: Epic.index_name).and_return(1000)
      expect(space_required_bytes).to eq(2000)
    end
  end
end
