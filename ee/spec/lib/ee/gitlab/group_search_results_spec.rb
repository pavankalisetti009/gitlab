# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GroupSearchResults do
  let!(:user) { build(:user) }
  let!(:group) { create(:group) }

  subject { described_class.new(user, query, group: group) }

  before do
    create(:group_member, group: group, user: user)
    group.add_owner(user)
    stub_licensed_features(epics: true)
  end

  describe '#epics' do
    context 'searching' do
      let(:query) { 'foo' }
      let!(:searchable_epic) { create(:epic, title: 'foo', group: group) }
      let!(:another_searchable_epic) { create(:epic, title: 'foo 2', group: group) }
      let!(:another_epic) { create(:epic) }

      it 'finds epics' do
        expect(subject.objects('epics')).to match_array([searchable_epic, another_searchable_epic])
      end
    end

    context 'ordering' do
      let(:scope) { 'epics' }
      let(:filters) { {} }

      let!(:old_result) { create(:epic, group: group, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:epic, group: group, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:epic, group: group, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:epic, group: group, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:epic, group: group, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:epic, group: group, title: 'updated very old', updated_at: 1.year.ago) }

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(user, 'sorted', Project.order(:id), group: group, sort: sort, filters: filters) }
        let(:results_updated) { described_class.new(user, 'updated', Project.order(:id), group: group, sort: sort, filters: filters) }
      end
    end
  end

  describe '#work_items' do
    let(:query) { 'foo' }
    let!(:work_item) { create(:work_item, :group_level, namespace: group, title: 'foo work item') }
    let!(:another_work_item) { create(:work_item, :group_level, namespace: group, title: 'foo another') }
    let!(:unrelated_work_item) { create(:work_item, :group_level, title: 'bar') }

    context 'when searching for work items' do
      it 'finds work items matching the query' do
        results = subject.work_items

        expect(results).to include(work_item, another_work_item)
        expect(results).not_to include(unrelated_work_item)
      end

      it 'includes descendants' do
        subgroup = create(:group, parent: group)
        subgroup_work_item = create(:work_item, :group_level, namespace: subgroup, title: 'foo subgroup')

        results = subject.work_items

        expect(results).to include(subgroup_work_item)
      end

      it 'excludes ancestors' do
        parent_group = create(:group)
        group.update!(parent: parent_group)
        parent_work_item = create(:work_item, :group_level, namespace: parent_group, title: 'foo parent')

        results = subject.work_items

        expect(results).not_to include(parent_work_item)
      end

      it 'searches by query using title' do
        results = subject.work_items

        expect(results.map(&:title)).to all(include('foo'))
      end

      it 'accepts custom finder params' do
        closed_work_item = create(:work_item, :group_level, namespace: group, title: 'foo closed', state: :closed)

        results = subject.work_items(state: 'closed')

        expect(results).to include(closed_work_item)
        expect(results).not_to include(work_item)
      end
    end

    context 'when applying sort' do
      let(:query) { 'sortable' }
      let!(:old_work_item) { create(:work_item, :group_level, namespace: group, title: 'sortable old', created_at: 2.days.ago) }
      let!(:new_work_item) { create(:work_item, :group_level, namespace: group, title: 'sortable new', created_at: 1.day.ago) }

      it 'applies sorting by created_at desc' do
        results_with_sort = described_class.new(user, 'sortable', group: group, sort: 'created_desc')
        sorted_results = results_with_sort.work_items

        expect(sorted_results.to_a).to match_array([new_work_item, old_work_item])
      end
    end
  end
end
