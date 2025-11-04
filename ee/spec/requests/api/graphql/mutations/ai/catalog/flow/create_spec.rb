# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_flow_create, params) }
  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:definition) do
    <<~YAML
      version: v1
      environment: ambient
      components:
        - name: main_agent
          type: AgentComponent
          prompt_id: test_prompt
      routers: []
      flow:
        entry_point: main_agent
    YAML
  end

  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      public: true,
      steps: nil,
      definition: definition
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item or version' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
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

  context 'when graphql params are invalid' do
    let(:name) { nil }
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include(
        'provided invalid value for',
        'name (Expected value to not be null)',
        'description (Expected value to not be null)'
      )
    end
  end

  context 'when model params are invalid' do
    let(:name) { '' }
    let(:description) { '' }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_flow_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank",
        "Name is too short (minimum is 3 characters)"
      )
      expect(graphql_data_at(:ai_catalog_flow_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data' do
    execute

    item = Ai::Catalog::Item.last
    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      item_type: Ai::Catalog::Item::FLOW_TYPE.to_s,
      public: true
    )
    expect(item.latest_version).to have_attributes(
      schema_version: ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION,
      version: '1.0.0',
      release_date: nil,
      definition: YAML.safe_load(definition).merge('yaml_definition' => definition)
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_flow_create, :item)).to match a_hash_including(
      'name' => name,
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'description' => description,
      'latestVersion' => a_hash_including('released' => false)
    )
  end

  context 'when release argument is true' do
    let(:params) { super().merge(release: true) }

    it 'releases the flow version' do
      execute

      expect(Ai::Catalog::ItemVersion.last.release_date).not_to be_nil
      expect(graphql_data_at(:ai_catalog_flow_create, :item)).to match a_hash_including(
        'latestVersion' => a_hash_including('released' => true)
      )
    end
  end

  context 'when add_to_project_when_created is true' do
    let(:params) { super().merge(add_to_project_when_created: true) }

    context 'and item is successfully added to the project' do
      it 'adds the created item to project' do
        execute

        item = Ai::Catalog::Item.last

        item_consumer = ::Ai::Catalog::ItemConsumer.for_item(item.id).first
        expect(item_consumer.project).to eq(project)
      end
    end

    context 'and item is created but not successfully added to the project' do
      it 'returns the item with a message' do
        allow_next_instance_of(::Ai::Catalog::ItemConsumers::CreateService) do |instance|
          expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Failure!'))
        end

        execute

        item = Ai::Catalog::Item.last

        expect(graphql_data_at(:ai_catalog_flow_create, :item)).to match(a_graphql_entity_for(item))
        expect(graphql_data_at(:ai_catalog_flow_create, :errors)).to contain_exactly("Failure!")
      end
    end
  end
end
