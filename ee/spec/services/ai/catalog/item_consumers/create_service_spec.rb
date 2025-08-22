# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/internal_events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::CreateService, feature_category: :workflow_catalog do
  let_it_be(:user) { create(:user) }
  let_it_be(:consumer_group) { create(:group, maintainers: user) }
  let_it_be(:consumer_project) { create(:project, group: consumer_group) }

  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:item) { create(:ai_catalog_item, item_type: :flow, project: item_project) }

  let(:container) { consumer_project }
  let(:params) do
    {
      item: item,
      enabled: true,
      locked: true
    }
  end

  subject(:execute) { described_class.new(container: container, current_user: user, params: params).execute }

  it_behaves_like 'ItemConsumers::InternalEventsTracking' do
    subject { described_class.new(container: container, current_user: user, params: params) }
  end

  shared_examples 'a failure' do |message|
    it 'does not create a catalog item consumer' do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }
    end

    it 'returns failure response with expected message' do
      response = execute

      expect(response).to be_error
      expect(response.message).to contain_exactly(message)
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

  context 'when the item is already configured in the project' do
    before do
      create(:ai_catalog_item_consumer, project: consumer_project, item: item)
    end

    it_behaves_like 'a failure', 'Item already configured'
  end

  context 'when the consumer is a group' do
    let(:container) { consumer_group }

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: nil,
        group: consumer_group,
        item: item,
        enabled: true,
        locked: true
      )
    end

    it 'tracks internal event with group namespace' do
      expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
        user: user,
        project: nil,
        namespace: consumer_group,
        additional_properties: {
          label: 'true',
          property: 'true'
        }
      )
    end

    context 'when the item is already configured in the group' do
      before do
        create(:ai_catalog_item_consumer, group: consumer_group, item: item)
      end

      it_behaves_like 'a failure', 'Item already configured'
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
    let(:user) do
      create(:user).tap do |user|
        consumer_project.add_maintainer(user)
        item_project.add_reporter(user)
      end
    end

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end

  context 'when the item is not a flow' do
    let(:item) { create(:ai_catalog_item, item_type: :agent, project: item_project) }

    it_behaves_like 'a failure', 'Catalog item is not a flow'
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
