# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Status, feature_category: :team_planning do
  subject(:status) { described_class.find(1) }

  describe 'validations' do
    it 'has the correct minimal structure for each item' do
      expect(described_class::ITEMS).to all(include(:id, :name, :color, :category))
    end

    it 'has unique names for all statuses' do
      name_occurrences = described_class::ITEMS.group_by { |item| item[:name].downcase }
      duplicates = name_occurrences.select { |_, items| items.size > 1 }

      error_message = duplicates.map do |name, items|
        item_details = items.map { |item| "ID: #{item[:id]}, Name: '#{item[:name]}'" }.join(", ")
        "Name '#{name}' is used by multiple items: [#{item_details}]"
      end.join("\n")

      expect(duplicates).to be_empty, error_message.empty? ? nil : "Duplicate status names found:\n#{error_message}"
    end
  end

  describe '#icon_name' do
    it 'returns the correct icon name for the status category' do
      expect(status.icon_name).to eq('status-waiting')
    end
  end

  describe '#matches_name?' do
    it 'returns true for case-insensitive name match' do
      expect(status.matches_name?('to do')).to be true
      expect(status.matches_name?('TO DO')).to be true
    end

    it 'returns false for non-matching name' do
      expect(status.matches_name?('in progress')).to be false
    end
  end

  it 'has the correct attributes' do
    is_expected.to have_attributes(
      id: 1,
      name: 'To do',
      color: '#737278',
      category: :to_do,
      position: 0
    )
  end

  it 'has default value for position' do
    expect(described_class.new.position).to eq(0)
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(ActiveModel::Model) }
    it { is_expected.to include(ActiveModel::Attributes) }
    # AR like methods are tested in this module
    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
  end
end
