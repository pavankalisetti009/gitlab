# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Status, feature_category: :team_planning do
  subject(:custom_status) { build_stubbed(:work_item_custom_status) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:lifecycles).through(:lifecycle_statuses) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:color) }
    it { is_expected.to validate_length_of(:color).is_at_most(7) }
    it { is_expected.to validate_presence_of(:category) }

    context 'with uniqueness validations' do
      subject(:custom_status) { create(:work_item_custom_status) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    end

    describe 'status per namespace limit validations' do
      let_it_be(:group) { create(:group) }
      let_it_be(:existing_status) { create(:work_item_custom_status, namespace: group) }

      before do
        stub_const('WorkItems::Statuses::Custom::Status::MAX_STATUSES_PER_NAMESPACE', 1)
      end

      it 'is invalid when exceeding maximum allowed statuses' do
        new_status = build(:work_item_custom_status, namespace: group)

        expect(new_status).not_to be_valid
        expect(new_status.errors[:namespace]).to include('can only have a maximum of 1 statuses.')
      end

      it 'allows updating attributes of an existing status when limit is reached' do
        existing_status.name = 'Updated Name'

        expect(existing_status).to be_valid
      end
    end

    context 'with invalid color' do
      it 'is invalid' do
        custom_status.color = '000000'
        expect(custom_status).to be_invalid
        expect(custom_status.errors[:color]).to include('must be a valid color code')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:category).with_values(described_class::CATEGORIES) }
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
    it { is_expected.to include(WorkItems::Statuses::Status) }
  end

  describe '#icon_name' do
    it 'returns the icon name based on the category' do
      expect(custom_status.icon_name).to eq('status-waiting')
    end
  end

  describe '#position' do
    it 'returns 0 as the default position' do
      expect(custom_status.position).to eq(0)
    end
  end
end
