# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, item_type: :flow, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_flow_version, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) { create(:ai_catalog_flow_version, version: '1.1.0', item: item) }

  let(:definition) do
    <<~YAML
      version: v1
      environment: ambient
      components:
        - name: updated_agent
          type: AgentComponent
          prompt_id: updated_prompt
          toolset:
            - gitlab_blob_search
            - grep
      routers: []
      flow:
        entry_point: updated_agent
    YAML
  end

  let(:params) do
    {
      item: item,
      name: 'New name',
      description: 'New description',
      public: true,
      release: true,
      definition: definition
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      YAML.safe_load(definition).merge('yaml_definition' => definition)
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when definition is provided and valid' do
        it 'updates attributes correctly' do
          execute_service

          expect(latest_version.reload.definition).to eq(expected_updated_definition)
          expect(item.reload).to have_attributes(
            name: 'New name',
            description: 'New description',
            public: true
          )
        end
      end

      context 'when flow is not a flow' do
        before do
          allow(item).to receive(:flow?).and_return(false)
        end

        it_behaves_like 'an error response', 'Flow not found'
      end

      it_behaves_like 'yaml definition update service behavior'
    end
  end

  describe 'audit events' do
    let(:execute_service) do
      service.execute
    end

    before_all do
      project.add_maintainer(user)
    end

    it 'creates audit events for the changes', :aggregate_failures do
      expect { execute_service }.to change { AuditEvent.count }.by(3)

      audit_events = AuditEvent.last(3)

      expect(audit_events[0]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[0].details).to include(
        custom_message: "Updated AI flow: Added tools: [gitlab_blob_search, grep], " \
          "Entry point changed from 'main_agent' to 'updated_agent', " \
          "Added components: [updated_agent], Removed components: [main_agent]",
        event_name: "update_ai_catalog_flow",
        target_type: "Ai::Catalog::Item"
      )

      expect(audit_events[1]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[1].details).to include(
        custom_message: 'Made AI flow public'
      )

      expect(audit_events[2]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id
      )
      expect(audit_events[2].details).to include(
        custom_message: 'Released version 1.1.0 of AI flow'
      )
    end

    context 'when update fails' do
      before do
        allow(item).to receive(:save).and_return(false)
        item.errors.add(:base, 'Item cannot be updated')
      end

      it 'does not create an audit event' do
        expect { execute_service }.not_to change { AuditEvent.count }
      end
    end
  end
end
