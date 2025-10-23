# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LabelLink, feature_category: :global_search do
  describe 'callback' do
    describe 'after_destroy' do
      let_it_be_with_reload(:label) { create(:label) }
      let_it_be(:label2) { create(:label) }

      context 'for issues' do
        let_it_be(:issue) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for issues which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue2).once
          label.destroy!
        end
      end

      context 'for epics' do
        let_it_be(:epic) { create(:labeled_epic, labels: [label]) }
        let_it_be(:epic2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:epic3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for epics which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(epic2).once
          label.destroy!
        end
      end

      context 'for merge requests' do
        let_it_be(:merge_request) { create(:labeled_merge_request, labels: [label]) }
        let_it_be(:merge_request2) { create(:labeled_merge_request, labels: [label]) }
        let_it_be(:merge_request3) { create(:labeled_merge_request, labels: [label2]) }

        it 'synchronizes elasticsearch only for merge requests which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(merge_request).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(merge_request2).once
          label.destroy!
        end
      end

      context 'for work items' do
        let_it_be(:work_item) { create(:work_item, labels: [label]) }
        let_it_be(:work_item2) { create(:work_item, labels: [label]) }
        let_it_be(:work_item3) { create(:work_item, labels: [label2]) }

        it 'synchronizes elasticsearch for work items which have deleted label attached' do
          # WorkItems are stored as Issues in the database due to inheritance,
          # so the callback receives Issue objects, not WorkItem objects
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).twice do |object|
            expect(object.class).to eq(Issue)
            expect([work_item.id, work_item2.id]).to include(object.id)
          end
          label.destroy!
        end
      end
    end
  end
end
