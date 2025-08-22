# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Create, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:consumer_group) { create(:group, maintainers: user) }
  let_it_be(:consumer_project) { create(:project, group: consumer_group) }

  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:item) { create(:ai_catalog_flow, project: item_project) }

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_create, params) }
  let(:target) { { project_id: consumer_project.to_global_id } }
  let(:params) do
    {
      target: target,
      item_id: item.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item consumer' do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }
    end
  end

  context 'when user is not authorized to create a consumer item in the consumer project' do
    let(:current_user) do
      create(:user).tap do |user|
        consumer_project.add_developer(user)
        item_project.add_developer(user)
      end
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when user is not authorized to read the catalog item' do
    let(:current_user) do
      create(:user).tap do |user|
        consumer_project.add_maintainer(user)
        item_project.add_reporter(user)
      end
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when target argument is provided neither group_id or project_id' do
    let(:target) { {} }

    it_behaves_like 'an invalid argument to the mutation', argument_name: :target
  end

  context 'when target is provided both group_id or project_id are provided' do
    let(:target) { super().merge({ group_id: consumer_group.to_global_id }) }

    it_behaves_like 'an invalid argument to the mutation', argument_name: :target
  end

  context 'when the item is an agent' do
    let(:item) { create(:ai_catalog_agent, project: item_project) }

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
        'enabled' => true,
        'locked' => true
      )
    end
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  it 'creates a catalog item consumer with expected data' do
    execute

    expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
      'item' => a_hash_including('id' => item.to_global_id.to_s),
      'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
      'enabled' => true,
      'locked' => true,
      'pinnedVersionPrefix' => nil
    )
  end

  context 'with a group_id' do
    let(:params) do
      {
        item_id: item.to_global_id,
        target: { group_id: consumer_group.to_global_id },
        enabled: false,
        locked: false,
        pinned_version_prefix: '1.0'
      }
    end

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'group' => a_hash_including('id' => consumer_group.to_global_id.to_s),
        'enabled' => false,
        'locked' => false,
        'pinnedVersionPrefix' => '1.0'
      )
    end
  end
end
