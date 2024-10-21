# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::RelatedEpicLinks::CreateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:target_epic) { create(:epic, group: group) }

  let(:params) do
    {
      target_issuable: target_epic,
      link_type: 'relates_to'
    }
  end

  subject(:execute) { described_class.new(epic, user, params).execute }

  before do
    stub_licensed_features(epics: true, related_epics: true)
  end

  shared_examples 'successful execution' do
    it 'creates a related epic link and a work item link' do
      expect { subject }
        .to change { Epic::RelatedEpicLink.count }.by(1)
        .and change { WorkItems::RelatedWorkItemLink.count }.by(1)

      expect(subject[:status]).to eq(:success)
      expect(subject[:created_references]).to contain_exactly(an_instance_of(Epic::RelatedEpicLink))
    end
  end

  shared_examples 'success' do
    context 'with target_issuable' do
      it_behaves_like 'successful execution'
    end

    context 'with issuable_references' do
      let(:params) do
        {
          issuable_references: [target_epic.to_reference],
          link_type: 'relates_to'
        }
      end

      it_behaves_like 'successful execution'
    end
  end

  shared_examples 'error' do
    it 'does not create a related epic link and returns an error message for epics instead of work items' do
      # Link it for for the first time
      described_class.new(epic, user, params).execute

      # Link it a second time
      expect { subject }
        .to change { Epic::RelatedEpicLink.count }.by(0)
        .and change { WorkItems::RelatedWorkItemLink.count }.by(0)

      expect(subject[:status]).to eq(:error)
      expect(subject[:message]).to eq("Epic(s) already assigned")
    end

    context 'when target issuable is empty' do
      let(:params) do
        {
          target_issuable: nil,
          link_type: 'relates_to'
        }
      end

      it 'does not create a related epic link and returns an error message when references are empty' do
        expect { subject }
          .to change { Epic::RelatedEpicLink.count }.by(0)
          .and change { WorkItems::RelatedWorkItemLink.count }.by(0)

        expect(subject[:status]).to eq(:error)
        expect(subject[:message]).to eq("No matching epic found. Make sure that you are adding a valid epic URL.")
      end
    end
  end

  describe '#execute' do
    context 'when feature flags are enabled' do
      before do
        stub_feature_flags(work_item_epics_ssot: true)
      end

      it_behaves_like 'success'
      it_behaves_like 'error'

      it 'calls the WorkItems::RelatedWorkItemLinks::CreateService with the correct params' do
        allow(WorkItems::RelatedWorkItemLinks::CreateService).to receive(:new).and_call_original
        expect(WorkItems::RelatedWorkItemLinks::CreateService).to receive(:new).with(epic.work_item, user,
          hash_including({ target_issuable: array_including(target_epic.work_item), link_type: 'relates_to' })
        ).and_call_original

        execute
      end
    end

    context 'when feature flags are disabled' do
      before do
        stub_feature_flags(work_item_epics_ssot: false)
      end

      it_behaves_like 'success'
      it_behaves_like 'error'

      it 'calls Epics::RelatedEpicLinks::CreateService' do
        allow(Epics::RelatedEpicLinks::CreateService).to receive(:new).and_call_original
        expect(Epics::RelatedEpicLinks::CreateService).to receive(:new)
          .with(epic, user, params).and_call_original

        execute
      end
    end
  end
end
