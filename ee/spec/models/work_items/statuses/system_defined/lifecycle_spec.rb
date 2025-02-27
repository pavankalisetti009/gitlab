# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Lifecycle, feature_category: :team_planning do
  subject(:lifecycle) { described_class.find(1) }

  describe 'validations' do
    it 'has the correct structure for each item' do
      described_class::ITEMS.each do |item|
        expect(item).to include(:id, :name, :work_item_base_types)
        expect(item[:work_item_base_types]).to be_an(Array)
      end
    end
  end

  describe '.of_work_item_base_type' do
    it 'returns the correct lifecycle for a given base type' do
      expect(described_class.of_work_item_base_type(:issue).id).to eq(1)
    end
  end

  describe '#for_base_type?' do
    it 'returns true for matching base types' do
      expect(lifecycle.for_base_type?(:issue)).to be true
      expect(lifecycle.for_base_type?(:task)).to be true
    end

    it 'returns false for non-matching base types' do
      expect(lifecycle.for_base_type?(:epic)).to be false
      expect(lifecycle.for_base_type?(:requirement)).to be false
      expect(lifecycle.for_base_type?(:ticket)).to be false
    end
  end

  describe '#work_item_types' do
    it 'returns work item types for the lifecycle base types' do
      expect(WorkItems::Type).to receive(:where).with(base_type: [:issue, :task])
      lifecycle.work_item_types
    end
  end

  describe '#statuses' do
    let(:statuses) { lifecycle.statuses }

    it 'returns statuses for the lifecycle' do
      # We could make this more explicit and check for concrete statuses
      # but this would increase coupling.
      expect(statuses).to be_an(Array)
      expect(statuses.first).to be_an(WorkItems::Statuses::SystemDefined::Status)
    end
  end

  describe '#find_available_status_by_name' do
    # Test here with a single existing record to keep the coupling down
    it 'returns the first status that matches the given name' do
      expect(lifecycle.find_available_status_by_name('in progress').id).to eq(2)
    end

    it 'returns nil if no status matches the given name' do
      expect(lifecycle.find_available_status_by_name('some_name')).to be_nil
    end
  end

  it 'has the correct attributes' do
    is_expected.to have_attributes(
      id: 1,
      name: 'Default',
      work_item_base_types: [:issue, :task]
    )
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(ActiveModel::Model) }
    it { is_expected.to include(ActiveModel::Attributes) }
    # AR like methods are tested in this module
    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
  end
end
