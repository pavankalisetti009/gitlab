# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Agent',
      description: 'Description',
      public: true,
      release: true,
      tools: [Ai::Catalog::BuiltInTool.find(1)],
      system_prompt: 'A',
      user_prompt: 'B',
      add_to_project_when_created: false
    }
  end

  subject(:response) { described_class.new(project: project, current_user: user, params: params).execute }

  before do
    enable_ai_catalog
  end

  describe '#execute', :freeze_time do
    shared_examples 'an error response' do |errors|
      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to match_array(Array(errors))
        expect(response.payload).to be_empty
      end

      it 'does not create an agent' do
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
        public: true,
        item_type: Ai::Catalog::Item::AGENT_TYPE.to_s
      )
      expect(item.latest_version).to have_attributes(
        schema_version: 1,
        version: '1.0.0',
        release_date: Time.zone.now,
        definition: {
          system_prompt: params[:system_prompt],
          tools: [1],
          user_prompt: params[:user_prompt]
        }.stringify_keys
      )
      expect(item.latest_released_version).to eq(item.latest_version)
    end

    it 'triggers create_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { response }
       .to trigger_internal_events('create_ai_catalog_item')
       .with(user: user, project: project, additional_properties: { label: 'agent' })
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

    context 'when passing only required arguments (test that mutation handles absence of optional args)' do
      let(:params) { super().except(:release, :tools, :user_prompt) }

      it 'returns a success response with item in payload' do
        expect(response).to be_success
        expect(response.payload[:item]).to be_a(Ai::Catalog::Item)
      end
    end
  end

  context 'when add_to_project_when_created is false' do
    it 'does not create item consumer' do
      expect { response }.not_to change { ::Ai::Catalog::ItemConsumer.count }
    end
  end

  context 'when add_to_project_when_created is true' do
    let(:params) { super().merge(add_to_project_when_created: true) }

    it 'adds the created item to project' do
      expect(response).to be_success

      item = response.payload[:item]
      item_consumer = ::Ai::Catalog::ItemConsumer.for_item(item.id).first
      expect(item_consumer.project).to eq(project)
      expect(item_consumer.pinned_version_prefix).to be_nil
    end

    context 'and ItemConsumer fails to be created' do
      it 'returns a success with errors from item consumer creation' do
        allow_next_instance_of(::Ai::Catalog::ItemConsumers::CreateService) do |instance|
          expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Failure!'))
        end

        expect(response.payload[:item]).to be_kind_of(Ai::Catalog::Item)
        expect(response.errors).to eq(['Failure!'])
      end
    end
  end
end
