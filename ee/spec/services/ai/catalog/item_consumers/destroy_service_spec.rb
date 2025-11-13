# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::DestroyService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  it_behaves_like 'ItemConsumers::EventsTracking' do
    subject { described_class.new(build(:ai_catalog_item_consumer), build(:user)) }
  end

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:response) { described_class.new(item_consumer, current_user).execute }

    context 'with a project level item consumer' do
      let_it_be_with_refind(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('You have insufficient permissions to delete this item consumer')
        end

        it 'does not track internal event on failure' do
          expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
        end
      end

      context 'when user has permission' do
        let(:current_user) { maintainer }

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
          expect(response).to be_success
        end

        it 'tracks internal event on successful deletion' do
          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: maintainer,
            project: project,
            namespace: nil
          ).and increment_usage_metrics('counts.count_total_delete_ai_catalog_item_consumer')
        end

        it 'creates an audit event on successful deletion', :aggregate_failures do
          expect { response }.to change { AuditEvent.count }.by(1)

          audit_event = AuditEvent.last

          expect(audit_event).to have_attributes(
            author: maintainer,
            entity_type: 'Project',
            entity_id: project.id,
            target_details: "#{item_consumer.item.name} (ID: #{item_consumer.item.id})"
          )
          expect(audit_event.details).to include(
            custom_message: 'Removed AI agent from project/group',
            event_name: 'disable_ai_catalog_agent',
            target_type: 'Ai::Catalog::Item'
          )
        end

        context 'when destroy fails' do
          before do
            allow(item_consumer).to receive(:destroy) do
              item_consumer.errors.add(:base, 'Deletion failed')
              false
            end
          end

          it 'returns an error' do
            expect { response }.not_to change { Ai::Catalog::ItemConsumer.count }
            expect(response).to be_error
            expect(response.message).to contain_exactly('Deletion failed')
          end

          it 'does not track internal event on failure' do
            expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
          end

          it 'does not create an audit event on failure' do
            expect { response }.not_to change { AuditEvent.count }
          end
        end
      end
    end

    context 'with a group level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, group: group) }

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('You have insufficient permissions to delete this item consumer')
        end

        it 'does not track internal event' do
          expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
        end
      end

      context 'when user has permission' do
        let(:current_user) { maintainer }

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
          expect(response).to be_success
        end

        it 'tracks internal event with group namespace' do
          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: maintainer,
            project: nil,
            namespace: group
          )
        end
      end
    end
  end
end
