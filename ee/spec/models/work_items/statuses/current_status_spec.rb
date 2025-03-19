# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::CurrentStatus, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item) }

  subject(:current_status) { build_stubbed(:work_item_current_status) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }

    describe 'belongs_to_fixed_items :system_defined_status' do
      # We don't have a matcher to test this in one line yet.
      # So let's check whether generated methods are present
      # and behave as expected.
      it { is_expected.to respond_to(:system_defined_status) }
      it { is_expected.to respond_to(:system_defined_status=) }
      it { is_expected.to respond_to(:system_defined_status_id) }
      it { is_expected.to respond_to(:system_defined_status_id=) }

      it 'returns correct association object' do
        expect(current_status.system_defined_status).to be_a(WorkItems::Statuses::SystemDefined::Status)
        expect(current_status.system_defined_status.id).to eq(1)
      end

      context 'when association id is changed' do
        let(:status_id) { 2 }

        before do
          current_status.system_defined_status_id = status_id
        end

        it 'returns correct association object' do
          expect(current_status.system_defined_status).to be_a(WorkItems::Statuses::SystemDefined::Status)
          expect(current_status.system_defined_status.id).to eq(status_id)
        end
      end
    end
  end

  describe 'validations' do
    it { is_expected.to be_valid } # factory is valid
    it { is_expected.to validate_presence_of(:work_item_id) }

    describe '#validate_status_exists' do
      context 'when system_defined_status is present' do
        it { is_expected.to be_valid }
      end

      context 'when system_defined_status is not present' do
        subject(:current_status) { build(:work_item_current_status, system_defined_status: nil) }

        it 'is not valid' do
          expect(current_status).not_to be_valid
          expect(current_status.errors[:system_defined_status]).to include(
            "not provided or references non-existent system defined status"
          )
        end
      end
    end
  end

  describe 'database check constraint for status associations' do
    subject(:current_status) { build(:work_item_current_status, work_item: work_item) }

    context 'when system_defined_status_id is present' do
      before do
        current_status.system_defined_status_id = 1
      end

      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when custom_status_id is present' do
      before do
        current_status.system_defined_status_id = nil
        current_status.custom_status_id = 1 # This is okay for now since we don't have a FK for the column yet
      end

      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when both system_defined_status_id and custom_status_id are present' do
      before do
        current_status.custom_status_id = 1 # This is okay for now since we don't have a FK for the column yet
      end

      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when neither system_defined_status_id nor custom_status_id are present' do
      before do
        current_status.system_defined_status_id = nil
      end

      it 'raises error' do
        expect { current_status.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe 'database sharding key trigger' do
    subject(:current_status) { create(:work_item_current_status, work_item: work_item) }

    it 'sets namespace_id based on work item' do
      expect(current_status.reset.namespace_id).to eq(work_item.namespace_id)
    end
  end

  describe '.for_work_items_with_statuses' do
    let_it_be(:work_item_2) { create(:work_item) }
    let_it_be(:work_item_3) { create(:work_item) }

    let_it_be(:system_defined_status_1) { WorkItems::Statuses::SystemDefined::Status.find(1) }
    let_it_be(:system_defined_status_2) { WorkItems::Statuses::SystemDefined::Status.find(2) }

    let_it_be(:current_status_1) do
      create(:work_item_current_status, work_item: work_item, system_defined_status: system_defined_status_1)
    end

    let_it_be(:current_status_2) do
      create(:work_item_current_status, work_item: work_item_2, system_defined_status: system_defined_status_2)
    end

    context 'when all work items have statuses' do
      let_it_be(:work_item_ids) { [work_item.id, work_item_2.id] }

      it 'returns all current statuses for the requested work items' do
        expect(described_class.for_work_items_with_statuses(work_item_ids)).to contain_exactly(current_status_1,
          current_status_2)
      end
    end

    context 'when work items have no statuses' do
      let_it_be(:work_item_ids) { [work_item_3.id] }

      it 'returns an empty array' do
        expect(described_class.for_work_items_with_statuses(work_item_ids)).to eq([])
      end
    end

    context 'with a mix of work items with and without statuses' do
      let_it_be(:work_item_ids) { [work_item.id, work_item_2.id, work_item_3.id] }

      it 'returns only the statuses that exist' do
        expect(described_class.for_work_items_with_statuses(work_item_ids)).to contain_exactly(current_status_1,
          current_status_2)
      end
    end

    context 'when no work item IDs are provided' do
      let_it_be(:work_item_ids) { [] }

      it 'returns an empty array' do
        expect(described_class.for_work_items_with_statuses(work_item_ids)).to eq([])
      end
    end
  end

  describe '#status' do
    it 'returns system_defined_status' do
      expect(current_status.status).to eq(current_status.system_defined_status)
    end
  end

  describe '#status=' do
    let(:system_defined_status) { WorkItems::Statuses::SystemDefined::Status.find(1) }

    it 'sets system_defined_status' do
      current_status.status = system_defined_status

      expect(current_status.system_defined_status_id).to eq(system_defined_status.id)
    end
  end
end
