# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project_maintainer) { create(:user) }
  let_it_be(:project_maintainer_not_in_group) { create(:user) }

  let_it_be(:consumer_group) { create(:group, owners: user, developers: project_maintainer) }
  let_it_be(:consumer_project) do
    create(:project, group: consumer_group, maintainers: [project_maintainer, project_maintainer_not_in_group])
  end

  let_it_be(:service_account) { create(:user, :service_account) }
  let_it_be(:service_account_user_detail) do
    create(:user_detail, user: service_account, provisioned_by_group: consumer_group)
  end

  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:item) { create(:ai_catalog_flow, public: true, project: item_project) }

  let_it_be(:item_latest_released_version) do
    create(:ai_catalog_flow_version, :released, item: item, version: '3.2.1')
  end

  let_it_be(:consumer_group_item_consumer) do
    create(:ai_catalog_item_consumer, pinned_version_prefix: '1.2.3', group: consumer_group, item: item,
      service_account: service_account)
  end

  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_group_item_consumer) { create(:ai_catalog_item_consumer, group: other_group, item: item) }

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_create, params) }
  let(:target) { { project_id: consumer_project.to_global_id } }
  let(:params) do
    {
      target: target,
      item_id: item.to_global_id,
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

  shared_examples 'a successful request' do |pinned_version_prefix:|
    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
        'pinnedVersionPrefix' => pinned_version_prefix
      )
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

  context 'when the user is a project maintainer and group developer' do
    let(:current_user) { project_maintainer }

    it_behaves_like 'a successful request', pinned_version_prefix: '1.2.3'
  end

  context 'when the user is a project maintainer and does not belong to the group' do
    let(:current_user) { project_maintainer_not_in_group }

    it_behaves_like 'a successful request', pinned_version_prefix: '1.2.3'
  end

  context 'when the parent_item_consumer ID does not exist' do
    let(:params) { super().merge(parent_item_consumer_id: "gid://gitlab/Ai::Catalog::ItemConsumer/non-existent-id") }
    let(:current_user) { project_maintainer_not_in_group }

    it 'returns a not found error' do
      execute

      expect(graphql_errors.first['message']).to eq(
        "The resource that you are attempting to access does not exist or " \
          "you don't have permission to perform this action"
      )
    end
  end

  context 'when the parent_item_consumer ID belongs to a different group' do
    let(:params) { super().merge(parent_item_consumer_id: other_group_item_consumer.to_global_id) }

    context 'when the user does not have access to the group' do
      it 'returns a not found error' do
        execute

        expect(graphql_errors.first['message']).to eq(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end

    # TODO: Add this test after the issue below. There will still be an error, but it will be a different error message.
    context 'when the user has access to the group', skip: 'Depends on https://gitlab.com/gitlab-org/gitlab/-/issues/580696'
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
    let_it_be(:item) { create(:ai_catalog_agent, public: true, project: consumer_project) }
    let_it_be(:consumer_group_item_consumer) do
      create(:ai_catalog_item_consumer, item: item, group: consumer_group, pinned_version_prefix: '3.2.1')
    end

    let_it_be(:item_latest_released_version) do
      create(:ai_catalog_agent_version, :released, item: item, version: '3.2.1')
    end

    it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'

    context 'when ai_catalog_agents feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_agents: false)
      end

      let(:params) { super().except(:parent_item_consumer_id) }

      it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'
    end
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  it_behaves_like 'a successful request', pinned_version_prefix: '1.2.3'

  context 'with a group_id' do
    let_it_be(:group) { create(:group, owners: user) }

    let(:params) do
      {
        item_id: item.to_global_id,
        target: { group_id: group.to_global_id }
      }
    end

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
        'serviceAccount' => a_hash_including('id' => service_account.to_global_id.to_s),
        'pinnedVersionPrefix' => '3.2.1'
      )
    end
  end

  context 'when item is a foundational chat agent' do
    let_it_be(:foundational_item) { create(:ai_catalog_agent, public: true, project: item_project, id: 348) }

    let(:params) do
      {
        target: target,
        item_id: foundational_item.to_global_id,
        parent_item_consumer_id: consumer_group_item_consumer.to_global_id
      }
    end

    it 'returns an error and does not create an item consumer' do
      stub_saas_features(gitlab_duo_saas_only: true)

      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to be_nil
      expect(graphql_data_at(:ai_catalog_item_consumer_create,
        :errors)).to eq(["Foundational agents must be configured in admin settings."])
    end
  end
end
