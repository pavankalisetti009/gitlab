# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_agent_create, params) do
      <<~FIELDS
        errors
        item {
          id
          name
          description
          project {
            id
          }
          public
          latestVersion {
            released
            ... on AiCatalogAgentVersion {
              systemPrompt
              tools {
                nodes {
                  id
                }
              }
              userPrompt
            }
          }
        }
      FIELDS
    end
  end

  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      public: true,
      release: true,
      system_prompt: 'A',
      tools: tools.map { |tool| global_id_of(tool) },
      user_prompt: 'B',
      add_to_project_when_created: false
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

      expect(graphql_data_at(:ai_catalog_agent_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank",
        "Name is too short (minimum is 3 characters)"
      )
      expect(graphql_data_at(:ai_catalog_agent_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data', :freeze_time do
    execute

    item = Ai::Catalog::Item.last

    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      public: true,
      item_type: Ai::Catalog::Item::AGENT_TYPE.to_s
    )
    expect(item.latest_version).to have_attributes(
      schema_version: 1,
      release_date: Time.zone.now,
      version: '1.0.0',
      definition: {
        system_prompt: params[:system_prompt],
        tools: tools.map(&:id),
        user_prompt: params[:user_prompt]
      }.stringify_keys
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_agent_create, :item)).to match a_hash_including(
      'name' => name,
      'description' => description,
      'project' => a_graphql_entity_for(project),
      'public' => true,
      'latestVersion' => {
        'released' => true,
        'systemPrompt' => params[:system_prompt],
        'tools' => {
          'nodes' => match_array(
            tools.map { |tool| a_graphql_entity_for(tool) }
          )
        },
        'userPrompt' => params[:user_prompt]
      }
    )
  end

  context 'when tools argument is missing' do
    let(:params) { super().except(:tools) }

    it 'creates an agent with empty tools array' do
      execute

      item = Ai::Catalog::Item.last

      expect(item.latest_version.definition['tools']).to eq([])
    end
  end

  context 'when passing only required arguments (test that mutation handles absence of optional args)' do
    let(:params) { super().except(:release, :tools, :user_prompt) }

    it 'works without errors' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_create, :errors)).to be_empty
    end

    it 'returns a new item with all required arguments' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_create, :item)).to match a_hash_including(
        'name' => name,
        'description' => description,
        'project' => a_graphql_entity_for(project),
        'public' => true,
        'latestVersion' => {
          'released' => false,
          'systemPrompt' => params[:system_prompt],
          'tools' => { 'nodes' => [] },
          'userPrompt' => ""
        }
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
        expect(graphql_data_at(:ai_catalog_agent_create, :item)).to match(a_graphql_entity_for(item))
        expect(graphql_data_at(:ai_catalog_agent_create, :errors)).to contain_exactly("Failure!")
      end
    end
  end
end
