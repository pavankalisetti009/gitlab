# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ProcessProjectDeleteEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:group) { create(:group) }
    let(:project_id) { 123 }

    let(:event) do
      Projects::ProjectDeletedEvent.new(data: {
        project_id: project_id,
        namespace_id: namespace_id
      })
    end

    let(:remove_project_service) { Vulnerabilities::NamespaceStatistics::RecalculateService }

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(Group).to receive(:by_id).with(namespace_id).and_return(class_double(Group, first: group_result))
      allow(remove_project_service).to receive(:execute)
    end

    context 'when there is no group associated with the event' do
      let(:namespace_id) { non_existing_record_id }
      let(:group_result) { nil }

      it 'does not call the service layer logic' do
        handle_event

        expect(remove_project_service).not_to have_received(:execute)
      end
    end

    context 'when there is a group and project_id associated with the event' do
      let(:namespace_id) { group.id }
      let(:group_result) { group }

      it 'calls the service layer logic with the correct parameters' do
        handle_event

        expect(remove_project_service).to have_received(:execute).with(
          project_id,
          group,
          deleted_project: true
        )
      end
    end
  end
end
