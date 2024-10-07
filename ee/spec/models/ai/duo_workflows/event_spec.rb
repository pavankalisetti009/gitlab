# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Event, type: :model, feature_category: :duo_workflow do
  let(:workflow) { create(:duo_workflows_workflow) }
  let_it_be(:project) { create(:project) }

  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:event_status) }

  describe 'enums' do
    it 'maps event_type to the correct integer values' do
      expect(described_class.event_types[:pause]).to eq(0)
      expect(described_class.event_types[:resume]).to eq(1)
      expect(described_class.event_types[:stop]).to eq(2)
      expect(described_class.event_types[:message]).to eq(3)
      expect(described_class.event_types[:response]).to eq(4)
    end

    it 'maps event_status to the correct integer values' do
      expect(described_class.event_statuses[:queued]).to eq(0)
      expect(described_class.event_statuses[:delivered]).to eq(1)
    end

    it 'returns the correct string for event_type' do
      event = described_class.new(event_type: 'pause')
      expect(event.event_type).to eq('pause')
    end

    it 'returns the correct string for event_status' do
      event = described_class.new(event_status: 'queued')
      expect(event.event_status).to eq('queued')
    end
  end

  describe 'scopes' do
    let!(:queued_event) { create(:duo_workflows_event, workflow: workflow, project: project, event_status: 'queued') }
    let!(:delivered_event) do
      create(:duo_workflows_event, workflow: workflow, project: project, event_status: 'delivered')
    end

    it 'returns only queued events' do
      expect(described_class.queued).to include(queued_event)
      expect(described_class.queued).not_to include(delivered_event)
    end

    it 'returns only delivered events' do
      expect(described_class.delivered).to include(delivered_event)
      expect(described_class.delivered).not_to include(queued_event)
    end
  end
end
