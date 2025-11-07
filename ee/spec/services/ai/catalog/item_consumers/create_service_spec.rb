# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/internal_events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:maintainer_user) { create(:user) }

  let_it_be(:consumer_group) { create(:group, owners: user, maintainers: maintainer_user) }
  let_it_be(:consumer_project) { create(:project, group: consumer_group) }

  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:item) { create(:ai_catalog_flow, public: true, project: item_project, name: 'item_name') }

  let_it_be(:service_account) { create(:user, :service_account) }

  let_it_be(:service_account_user_detail) do
    create(:user_detail, user: service_account, provisioned_by_group: consumer_group)
  end

  let_it_be(:parent_item_consumer) do
    create(:ai_catalog_item_consumer, group: consumer_group, item: item, service_account: service_account)
  end

  let(:container) { consumer_project }
  let(:params) { { item:, parent_item_consumer: } }

  subject(:execute) { described_class.new(container: container, current_user: user, params: params).execute }

  before do
    enable_ai_catalog
  end

  it_behaves_like 'ItemConsumers::InternalEventsTracking' do
    subject { described_class.new(container: container, current_user: user, params: params) }
  end

  shared_examples 'a failure' do |message|
    it 'does not create any records' do
      expect { execute }.to not_change { Ai::FlowTrigger.count }
        .and not_change { Ai::Catalog::ItemConsumer.count }
    end

    it 'returns failure response with expected message' do
      response = execute

      expect(response).to be_error

      if message.is_a?(Array)
        expect(response.message).to match_array(message)
      else
        expect(response.message).to contain_exactly(message)
      end
    end

    it 'does not track internal event' do
      expect { execute }.not_to trigger_internal_events('create_ai_catalog_item_consumer')
    end
  end

  it 'creates a catalog item consumer with expected data' do
    execute

    expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
      project: consumer_project,
      group: nil,
      parent_item_consumer: parent_item_consumer,
      item: item,
      enabled: true,
      locked: true
    )
  end

  it 'tracks internal event on successful creation' do
    expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
      user: user,
      project: consumer_project,
      namespace: nil,
      additional_properties: {
        label: 'true',
        property: 'true'
      }
    ).and increment_usage_metrics('counts.count_total_create_ai_catalog_item_consumer')
  end

  context 'when parent item consumer is not passed' do
    let_it_be(:parent_item_consumer) { nil }

    context 'when item is a flow' do
      let_it_be(:item) { create(:ai_catalog_flow, public: true, project: item_project) }

      it_behaves_like 'a failure', "Project item must have a parent item consumer"
    end

    context 'when item is a third_party_flow' do
      let_it_be(:item) { create(:ai_catalog_third_party_flow, public: true, project: item_project) }

      it_behaves_like 'a failure', "Project item must have a parent item consumer"
    end

    context 'when item is an agent' do
      let_it_be(:item) { create(:ai_catalog_agent, public: true, project: item_project) }

      it 'creates the agent' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
      end
    end
  end

  context 'when the item is already configured in the project' do
    before do
      create(:ai_catalog_item_consumer, project: consumer_project, item: item)
    end

    it_behaves_like 'a failure', 'Item already configured'
  end

  context 'when the consumer is a group' do
    let_it_be(:group) { create(:group, owners: user, maintainers: maintainer_user, name: "Group name") }
    let(:parent_item_consumer) { nil }
    let(:container) { group }

    let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

    before do
      stub_licensed_features(service_accounts: true)
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive(:seats).and_return(User.service_account.count + 2)
    end

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: nil,
        group: group,
        parent_item_consumer: nil,
        item: item,
        enabled: true,
        locked: true
      )
    end

    it 'tracks internal event with group namespace' do
      expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
        user: user,
        project: nil,
        namespace: group,
        additional_properties: {
          label: 'true',
          property: 'true'
        }
      )
    end

    context 'when the item is already configured in the group' do
      before do
        create(:ai_catalog_item_consumer, group:, item:)
      end

      it_behaves_like 'a failure', 'Item already configured'
    end

    it 'creates a service account and attaches it to the item consumer' do
      expect(::Namespaces::ServiceAccounts::CreateService).to receive(:new).and_call_original

      expect { execute }.to change { User.count }.by(1)
      service_account = User.last
      expect(service_account).to be_service_account
      expect(service_account).to have_attributes(
        username: "ai-item_name-group-name", provisioned_by_group_id: group.id
      )
      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(service_account:)
    end

    context 'when group is not a top-level group' do
      let_it_be(:child_group) { create(:group, parent: consumer_group, owners: user, maintainers: maintainer_user) }

      let(:container) { child_group }

      it 'does not create a service account' do
        expect(::Namespaces::ServiceAccounts::CreateService).not_to receive(:new)

        expect { execute }.not_to change { User.count }
      end
    end

    context 'when instance setting disallows top-level group owners to create service accounts' do
      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
      end

      it 'does not create a service account but still creates the item consumer' do
        expect { execute }
          .to not_change { User.service_account.count }
          .and change { Ai::Catalog::ItemConsumer.count }.by(1)

        expect(execute).to be_success
        expect(Ai::Catalog::ItemConsumer.last.service_account).to be_nil
      end
    end

    context 'when the user is not an owner of the group' do
      subject(:execute) do
        described_class.new(container: container, current_user: maintainer_user, params: params).execute
      end

      it 'does not attempt to create a service account but creates an item consumer' do
        expect(::Namespaces::ServiceAccounts::CreateService).not_to receive(:new).and_call_original

        expect { execute }.to not_change { User.count }
          .and change { Ai::Catalog::ItemConsumer.count }.by(1)
      end
    end

    context 'when the service account username already exists' do
      let_it_be(:existing_service_account_with_same_name) do
        create(:user, :with_namespace, :service_account, username: "ai-item_name-group-name")
      end

      it 'logs the error' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          "Failed to create service account with name 'ai-item_name-group-name': Username has already been taken"
        )

        execute
      end

      it_behaves_like 'a failure', 'Username has already been taken'
    end

    context 'when creating the service account fails' do
      before do
        allow(::Namespaces::ServiceAccounts::CreateService).to receive_message_chain(:new, :execute)
          .and_return(ServiceResponse.error(message: 'service account error'))
      end

      it_behaves_like 'a failure', 'service account error'
    end

    context 'when creating the item consumer fails' do
      it 'does not create a service account' do
        allow_next_instance_of(Ai::Catalog::ItemConsumer) do |item_consumer|
          allow(item_consumer).to receive(:save).and_return(false)
        end

        expect { execute }.not_to change { User.count }
      end
    end
  end

  context 'when user is not authorized to create a consumer item in the consumer project' do
    let(:user) do
      create(:user).tap do |user|
        consumer_project.add_developer(user)
        item_project.add_developer(user)
      end
    end

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end

  context 'when user is not authorized to read the catalog item' do
    let_it_be(:item) { create(:ai_catalog_flow, public: false, project: item_project) }

    let(:user) do
      create(:user).tap do |user|
        consumer_project.add_maintainer(user)
        item_project.add_reporter(user)
      end
    end

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end

  context 'when the item is an agent' do
    let(:item) { create(:ai_catalog_agent, public: true, project: item_project) }
    let(:parent_item_consumer) { nil }

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: consumer_project,
        group: nil,
        item: item,
        enabled: true,
        locked: true
      )
    end
  end

  context 'when passing trigger_types' do
    let(:params) { super().merge(trigger_types: ['mention']) }

    it 'creates the flow triggers' do
      expect { execute }.to change { Ai::FlowTrigger.count }.by(1)
      expect(Ai::FlowTrigger.last).to have_attributes(
        project_id: consumer_project.id,
        event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]],
        user_id: service_account.id
      )
    end

    context 'when container is a group' do
      let(:container) { consumer_group }
      let(:parent_item_consumer) { nil }

      it_behaves_like 'a failure', "Flow triggers can only be set for projects"
    end

    context 'when item is an agent' do
      let_it_be(:item) { create(:ai_catalog_agent, public: true, project: item_project) }

      it_behaves_like(
        'a failure', ["Flow trigger ai_catalog_item_consumer is not a flow", "Parent item consumer must be blank"]
      )
    end
  end

  context 'when the item can be seen by user but is is private to another project' do
    let_it_be(:item) { create(:ai_catalog_flow, public: false, project: item_project) }

    let_it_be(:private_item_parent_item_consumer) do
      # We get 'Item is private to another project' currently, but we will soon allow this
      build(:ai_catalog_item_consumer, group: consumer_group, item: item, service_account: service_account)
        .tap { |item| item.save!(validate: false) }
    end

    it_behaves_like 'a failure', 'Item is private to another project'
  end

  context 'when the item is private to the project' do
    let_it_be(:item) { create(:ai_catalog_flow, public: false, project: consumer_project) }

    let_it_be(:private_item_parent_item_consumer) do
      # We get 'Item is private to another project' currently, but we will soon allow this
      build(:ai_catalog_item_consumer, group: consumer_group, item: item, service_account: service_account)
        .tap { |item| item.save!(validate: false) }
    end

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: consumer_project,
        group: nil,
        item: item,
        enabled: true,
        locked: true
      )
    end
  end

  context 'when the item is private to another project, and the user does not have permission to see the item' do
    let(:item) { create(:ai_catalog_flow, public: false) }

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end

  context 'when save fails' do
    context 'when the model is invalid' do
      let(:params) { super().merge(pinned_version_prefix: '1' * 51) }

      it_behaves_like 'a failure', 'Pinned version prefix is too long (maximum is 50 characters)'
    end

    context 'when something else goes wrong' do
      before do
        allow_next_instance_of(Ai::Catalog::ItemConsumer) do |instance|
          allow(instance).to receive(:save).and_return(false)
        end
      end

      it_behaves_like 'a failure', 'Failed to create item consumer'
    end
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end
end
