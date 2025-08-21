# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::ParentLink, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'associations' do
    it do
      is_expected.to have_one(:epic_issue).class_name('EpicIssue')
        .with_foreign_key('work_item_parent_link_id')
        .inverse_of(:work_item_parent_link)
    end

    it do
      is_expected.to have_one(:epic).class_name('Epic')
        .with_foreign_key('work_item_parent_link_id')
        .inverse_of(:work_item_parent_link)
    end
  end

  describe '#validate_legacy_hierarchy' do
    context 'when assigning a parent with type Epic' do
      let_it_be_with_reload(:issue) { create(:work_item, project: project) }
      let_it_be(:legacy_epic) { create(:epic, group: group) }
      let_it_be(:epic) { create(:work_item, :epic, project: project) }

      subject { described_class.new(work_item: issue, work_item_parent: epic) }

      it 'is valid for child with no legacy epic' do
        expect(subject).to be_valid
      end

      it 'is invalid for child with existing legacy epic', :aggregate_failures do
        create(:epic_issue, epic: legacy_epic, issue: issue)

        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to include('Work item already assigned to an epic')
      end
    end
  end
end
