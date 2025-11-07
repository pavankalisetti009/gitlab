# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:consumer_group) { create(:group, owners: user) }
  let_it_be(:consumer_project) { create(:project, group: consumer_group) }

  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:item) { create(:ai_catalog_flow, public: true, project: item_project) }

  let_it_be(:consumer_group_item_consumer) do
    create(:ai_catalog_item_consumer, group: consumer_group, item: item)
  end

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_create, params) }
  let(:target) { { project_id: consumer_project.to_global_id } }
  let(:params) do
    {
      target: target,
      item_id: item.to_global_id,
      pinned_version_prefix: '1.1',
      parent_item_consumer_id: consumer_group_item_consumer.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

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
    let_it_be(:item) { create(:ai_catalog_flow, public: false, project: item_project) }

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
    let(:item) { create(:ai_catalog_agent, public: true, project: item_project) }

    let(:params) { super().except(:parent_item_consumer_id) }

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
        'pinnedVersionPrefix' => '1.1'
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
      'pinnedVersionPrefix' => '1.1'
    )
  end

  context 'with a group_id' do
    let_it_be(:group) { create(:group, owners: user) }

    let(:params) do
      {
        item_id: item.to_global_id,
        target: { group_id: group.to_global_id },
        pinned_version_prefix: '1.0'
      }
    end

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'group' => a_hash_including('id' => group.to_global_id.to_s),
        'pinnedVersionPrefix' => '1.0'
      )
    end

    context 'when group is a top-level group' do
      let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

      before do
        stub_licensed_features(service_accounts: true)
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(User.service_account.count + 2)
      end

      it 'creates a service account and attaches it to the item consumer' do
        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
          'serviceAccount' => a_hash_including('id' => service_account.to_global_id.to_s)
        )
      end
    end
  end
end
