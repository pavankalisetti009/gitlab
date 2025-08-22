# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Update, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_item_consumer_update, params) do
      <<~MUTATION
      errors
      itemConsumer {
        id
        enabled
        locked
      }
      MUTATION
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_item_consumer_update) }
  let(:params) do
    {
      id: item_consumer.to_global_id,
      enabled: false,
      locked: false,
      pinned_version_prefix: '1.0'
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the item consumer' do
      expect { execute }.not_to change { item_consumer.reload.attributes }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the item consumer does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemConsumer', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when item consumer update fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::ItemConsumers::UpdateService) do |service|
        allow(service).to receive(:item_consumer).and_return(item_consumer)
      end

      allow(item_consumer).to receive(:update).and_return(false)
      item_consumer.errors.add(:base, 'Update failed')
    end

    it 'returns the service error message and item consumer with original attributes' do
      execute

      expect(graphql_dig_at(mutation_response, :item_consumer, :enabled)).to be(true)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly("Update failed")
    end
  end

  context 'when update succeeds' do
    it 'updates the item consumer and returns a success response' do
      execute

      expect(item_consumer.reload).to have_attributes(
        enabled: false,
        locked: false,
        pinned_version_prefix: '1.0'
      )
      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
      expect(graphql_dig_at(mutation_response, :item_consumer)).to match(
        a_graphql_entity_for(item_consumer, :enabled, :locked)
      )
    end
  end
end
