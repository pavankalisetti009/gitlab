# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::DestroyService, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax
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
    let_it_be(:owner) { create(:user) }

    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer, owners: owner) }

    let_it_be(:service_account) { create(:user, :service_account) }
    let_it_be(:service_account_user_details) do
      create(:user_detail, user: service_account, provisioned_by_group: group)
    end

    let_it_be(:project) { create(:project, developers: service_account, group: group) }
    let_it_be(:item) { create(:ai_catalog_flow) }

    let_it_be(:third_party_flow_item) { create(:ai_catalog_third_party_flow, project: project) }

    let_it_be(:parent_item_consumer) { create(:ai_catalog_item_consumer, group:, item:, service_account:) }

    subject(:response) { described_class.new(item_consumer, current_user).execute }

    shared_examples 'creates an audit event on deletion' do |entity_type:|
      it 'creates an audit event on successful deletion', :aggregate_failures do
        event_name = "disable_ai_catalog_#{item_consumer.item.item_type}"
        entity_id = entity_type == 'Project' ? project.id : group.id
        entity_name = entity_type == 'Project' ? 'project' : 'group'

        type_display_name = if item_consumer.item.item_type == 'third_party_flow'
                              'external agent'
                            else
                              item_consumer.item.item_type
                            end

        expect { response }.to change { AuditEvent.count }

        audit_event = AuditEvent.last

        expect(audit_event).to have_attributes(
          author: current_user,
          entity_type: entity_type,
          entity_id: entity_id,
          target_details: "#{item_consumer.item.name} (ID: #{item_consumer.item.id})"
        )
        expect(audit_event.details).to include(
          custom_message: "Disabled AI #{type_display_name} for #{entity_name}",
          event_name: event_name,
          target_type: 'Ai::Catalog::Item'
        )
      end
    end

    context 'with a project level item consumer' do
      let_it_be_with_refind(:item_consumer) do
        create(:ai_catalog_item_consumer, item:, project:, parent_item_consumer:)
      end

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

        it 'removes the service account from the project' do
          expect { response }.to change { project.team.members.count }.by(-1)
          expect(project.team.users.pluck(:id)).not_to include(service_account.id)
        end

        context 'when removing the service account member fails' do
          before do
            allow_next_instance_of(Members::DestroyService) do |instance|
              allow(instance).to receive(:execute) do |member|
                member.errors.add(:base, 'Deletion failed')
              end
            end
          end

          it 'does not delete the item consumer' do
            expect { response }.not_to change { Ai::Catalog::ItemConsumer.count }
            expect(response).to be_error
            expect(response.message).to contain_exactly('Service account membership: Deletion failed')
          end
        end

        context 'when there is no service account membership in the project' do
          let_it_be(:project) { create(:project, group: group) }
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, parent_item_consumer:, project:, item:)
          end

          it 'does not fail' do
            expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
            expect(response).to be_success
          end
        end

        it 'tracks internal event on successful deletion' do
          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: maintainer,
            project: project,
            namespace: nil
          ).and increment_usage_metrics('counts.count_total_delete_ai_catalog_item_consumer')
        end

        it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'

        context 'when item is an agent' do
          let_it_be(:agent_item) { create(:ai_catalog_agent, project: project) }
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, project: project, item: agent_item)
          end

          it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'
        end

        context 'when item is a third_party_flow' do
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, project: project, item: third_party_flow_item)
          end

          it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'
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
      let(:item_consumer) { parent_item_consumer }
      let(:cannot_delete_consumer_message) { 'You have insufficient permissions to delete this item consumer' }
      let(:cannot_delete_service_account_message) { 'User does not have permission to delete a service account.' }

      context 'when user is owner with all permissions' do
        let(:current_user) { owner }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          stub_licensed_features(service_accounts: true)
        end

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)

          expect(response).to be_success
        end

        it 'deletes the service account' do
          expect(DeleteUserWorker)
            .to receive(:perform_async)
            .with(current_user.id, service_account.id, { skip_authorization: true })

          response
        end

        it 'tracks internal event with group namespace' do
          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: owner,
            project: nil,
            namespace: group
          )
        end

        it_behaves_like 'creates an audit event on deletion', entity_type: 'Group'
      end

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly(cannot_delete_consumer_message)
        end

        it 'does not track internal event' do
          expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
        end

        it 'does not create an audit event on failure' do
          expect { response }.not_to change { AuditEvent.count }
        end
      end

      where(:user, :service_accounts_feature, :allow_create_service_accounts, :result, :message) do
        ref(:developer)  | false | false | false  | ref(:cannot_delete_consumer_message)
        ref(:maintainer) | false | false | false  | ref(:cannot_delete_service_account_message)
        ref(:owner)      | false | false | false  | ref(:cannot_delete_service_account_message)

        ref(:developer)  | true | false | false   | ref(:cannot_delete_consumer_message)
        ref(:maintainer) | true | false | false   | ref(:cannot_delete_service_account_message)
        ref(:owner)      | true | false | false   | ref(:cannot_delete_service_account_message)

        ref(:developer)  | false | true | false   | ref(:cannot_delete_consumer_message)
        ref(:maintainer) | false | true | false   | ref(:cannot_delete_service_account_message)
        ref(:owner)      | false | true | false   | ref(:cannot_delete_service_account_message)

        ref(:developer)  | true | true  | false   | ref(:cannot_delete_consumer_message)
        ref(:maintainer) | true | true  | false   | ref(:cannot_delete_service_account_message)
        ref(:owner)      | true | true  | true    | nil
      end

      with_them do
        let(:current_user) { user }

        before do
          stub_ee_application_setting(
            allow_top_level_group_owners_to_create_service_accounts: allow_create_service_accounts
          )
          stub_licensed_features(service_accounts: service_accounts_feature)
        end

        it 'returns appropriate result', :aggregate_failures do
          expect(response.success?).to eq(result)

          expect(response.message).to contain_exactly(message) if message
        end
      end
    end
  end
end
