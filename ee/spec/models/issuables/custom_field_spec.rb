# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomField, feature_category: :team_planning do
  subject(:custom_field) { build(:custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:select_options) }
    it { is_expected.to have_many(:work_item_type_custom_fields) }
    it { is_expected.to have_many(:work_item_types) }

    it 'orders select_options by position' do
      custom_field.save!

      option_1 = create(:custom_field_select_option, custom_field: custom_field, position: 2)
      option_2 = create(:custom_field_select_option, custom_field: custom_field, position: 1)

      expect(custom_field.select_options).to eq([option_2, option_1])
    end

    it 'orders work_item_types by name' do
      custom_field.save!

      issue_type = create(:work_item_type, :issue)
      incident_type = create(:work_item_type, :incident)
      task_type = create(:work_item_type, :task)

      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: incident_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

      expect(custom_field.work_item_types).to eq([incident_type, issue_type, task_type])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id).case_insensitive }
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }

    let_it_be(:custom_field) { create(:custom_field, namespace: group, name: 'ZZZ') }
    let_it_be(:custom_field_2) { create(:custom_field, namespace: group, name: 'CCC') }
    let_it_be(:custom_field_archived) { create(:custom_field, :archived, namespace: group, name: 'AAA') }
    let_it_be(:other_custom_field) { create(:custom_field, namespace: create(:group), name: 'BBB') }

    describe '.of_namespace' do
      it 'returns custom fields of the given namespace' do
        expect(described_class.of_namespace(group)).to contain_exactly(
          custom_field, custom_field_2, custom_field_archived
        )
      end
    end

    describe '.active' do
      it 'returns active fields' do
        expect(described_class.active).to contain_exactly(
          custom_field, custom_field_2, other_custom_field
        )
      end
    end

    describe '.archived' do
      it 'returns archived fields' do
        expect(described_class.archived).to contain_exactly(
          custom_field_archived
        )
      end
    end

    describe '.ordered_by_status_and_name' do
      it 'returns active fields first, ordered by name' do
        expect(described_class.ordered_by_status_and_name).to eq([
          other_custom_field, custom_field_2, custom_field, custom_field_archived
        ])
      end
    end

    describe 'work item type scopes' do
      let_it_be(:issue_type) { create(:work_item_type, :issue) }
      let_it_be(:task_type) { create(:work_item_type, :task) }

      before_all do
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

        create(:work_item_type_custom_field, custom_field: custom_field_2, work_item_type: issue_type)
      end

      describe '.without_any_work_item_types' do
        it 'returns custom fields that are not associated with any work item type' do
          expect(described_class.without_any_work_item_types).to contain_exactly(
            custom_field_archived, other_custom_field
          )
        end
      end

      describe '.with_work_item_types' do
        context 'with empty array' do
          it 'returns custom fields that are not associated with any work item type' do
            expect(described_class.with_work_item_types([])).to contain_exactly(
              custom_field_archived, other_custom_field
            )
          end
        end

        context 'with array of work item type IDs' do
          it 'returns custom fields that match the work item type IDs' do
            expect(described_class.with_work_item_types([issue_type.id, task_type.id])).to contain_exactly(
              custom_field
            )
          end
        end

        context 'with array of work item type objects' do
          it 'returns custom fields that match the work item types' do
            expect(described_class.with_work_item_types([issue_type, task_type])).to contain_exactly(
              custom_field
            )
          end
        end
      end
    end
  end

  describe '#active?' do
    it 'returns true when archived_at is nil' do
      field = build(:custom_field, archived_at: nil)

      expect(field.active?).to eq(true)
    end

    it 'returns false when archived_at is set' do
      field = build(:custom_field, archived_at: Time.current)

      expect(field.active?).to eq(false)
    end
  end
end
