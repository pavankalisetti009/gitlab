# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::DestroyService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseDestroyService do
    let_it_be_with_reload(:incorrect_item_type) { create(:ai_catalog_flow, project: project) }
    let!(:item) { create(:ai_catalog_agent, public: true, project: project) }
    let(:not_found_error) { 'Agent not found' }
  end

  describe 'audit events' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, maintainers: user) }
    let_it_be(:item) { create(:ai_catalog_agent, project: project) }

    let(:params) { { item: item } }

    subject(:execute_service) { described_class.new(project: project, current_user: user, params: params).execute }

    it 'creates an audit event', :aggregate_failures do
      expect { execute_service }.to change { AuditEvent.count }.by(1)

      audit_event = AuditEvent.last

      expect(audit_event).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_event.details).to include(
        custom_message: 'Deleted AI agent',
        event_name: 'delete_ai_catalog_agent',
        target_type: 'Ai::Catalog::Item'
      )
    end

    context 'when destroy fails' do
      before do
        allow(item).to receive(:destroy).and_return(false)
        item.errors.add(:base, 'Item cannot be destroyed')
      end

      it 'does not create an audit event' do
        expect { execute_service }.not_to change { AuditEvent.count }
      end
    end
  end
end
