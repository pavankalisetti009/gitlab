# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:user) { maintainer }
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
      name: 'Flow',
      description: 'Description',
      public: true,
      release: true,
      definition: definition
    }
  end

  subject(:response) { described_class.new(project: project, current_user: user, params: params).execute }

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    shared_examples 'an error response' do |errors|
      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to match_array(Array(errors))
        expect(response.payload).to be_empty
      end

      it 'does not create a flow' do
        expect { response }.not_to change { Ai::Catalog::Item.count }
      end

      it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { response }
          .not_to trigger_internal_events('create_ai_catalog_item')
      end
    end

    it 'returns a success response with item in payload' do
      expect(response).to be_success
      expect(response.payload[:item]).to be_a(Ai::Catalog::Item)
    end

    it 'creates a catalog item and version with expected data' do
      expect { response }.to change { Ai::Catalog::Item.count }.by(1)
        .and change { Ai::Catalog::ItemVersion.count }.by(1)

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
        definition: YAML.safe_load(definition).merge('yaml_definition' => definition)
      )
      expect(item.latest_released_version).to eq(item.latest_version)
    end

    it 'triggers create_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { response }
       .to trigger_internal_events('create_ai_catalog_item')
       .with(user: user, project: project, additional_properties: { label: 'flow' })
       .and increment_usage_metrics(
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_weekly',
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_monthly',
         'counts.count_total_create_ai_catalog_item'
       )
    end

    context 'when the version is not being released' do
      let(:params) { super().merge(release: false) }

      it 'creates a draft version' do
        expect { response }.to change { Ai::Catalog::ItemVersion.count }

        item = Ai::Catalog::Item.last

        expect(item.latest_version).to be_draft
        expect(item.latest_released_version).to be_nil
      end
    end

    context 'when there is a validation issue' do
      before do
        params[:name] = nil
      end

      it_behaves_like 'an error response', ["Name can't be blank"]
    end

    it_behaves_like 'yaml definition create service behavior'

    context 'when user is a developer' do
      let(:user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when global_ai_catalog feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when ai_catalog_flows feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_flows: false)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end
  end

  context 'when add_to_project_when_created is true' do
    let(:params) { super().merge(add_to_project_when_created: true) }

    it 'adds the created item to project' do
      expect(response).to be_success

      item = response.payload[:item]
      item_consumer = ::Ai::Catalog::ItemConsumer.for_item(item.id).first
      expect(item_consumer.project).to eq(project)
    end

    context 'and ItemConsumer fails to be created' do
      it 'returns a success with errors from item consumer creation' do
        allow_next_instance_of(::Ai::Catalog::ItemConsumers::CreateService) do |instance|
          expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Failure!'))
        end

        expect(response.payload[:item]).to be_kind_of(Ai::Catalog::Item)
        expect(response.message).to eq(['Failure!'])
      end
    end
  end
end
