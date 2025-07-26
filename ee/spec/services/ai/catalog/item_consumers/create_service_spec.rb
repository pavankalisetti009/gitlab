# frozen_string_literal: true

require 'spec_helper'

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

  shared_examples 'a failure' do |message|
    it 'does not create a catalog item consumer' do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }
    end

    it 'returns failure response with expected message' do
      response = execute

      expect(response).to be_error
      expect(response.message).to contain_exactly(message)
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

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'a failure', 'Item does not exist, or you have insufficient permissions'
  end
end
