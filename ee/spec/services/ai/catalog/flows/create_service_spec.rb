# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CreateService, feature_category: :workflow_catalog do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:v1_0) { create(:ai_catalog_agent_version, item: agent, version: '1.0.0') }
  let_it_be(:v1_1) { create(:ai_catalog_agent_version, item: agent, version: '1.1.0') }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Agent',
      description: 'Description',
      public: true,
      steps: [
        { agent: agent }
      ]
    }
  end

  subject(:response) { described_class.new(project: project, current_user: user, params: params).execute }

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
      expect(item.versions.first).to have_attributes(
        schema_version: 1,
        version: '1.0.0',
        definition: {
          steps: [
            {
              agent_id: agent.id, current_version_id: v1_1.id, pinned_version_prefix: nil
            }.stringify_keys
          ],
          triggers: []
        }.stringify_keys
      )
    end

    it 'trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
      expect { response }
       .to trigger_internal_events('create_ai_catalog_item')
       .with(user: user, project: project, additional_properties: { label: 'flow' })
       .and increment_usage_metrics(
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_weekly',
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_monthly'
       )
    end

    context 'when there is a validation issue' do
      before do
        params[:name] = nil
      end

      it_behaves_like 'an error response', ["Name can't be blank", 'Versions is invalid']
    end

    context 'when including a pinned_version_prefix' do
      let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '1.0' }]) }

      it 'sets the correct current_version_id' do
        response

        item = Ai::Catalog::Item.last
        expect(item.versions.first.definition['steps'].first).to match a_hash_including(
          'agent_id' => agent.id, 'current_version_id' => v1_0.id, 'pinned_version_prefix' => '1.0'
        )
      end

      context 'when the prefix is not valid' do
        let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '2' }]) }

        it 'raises an ArgumentError' do
          expect { response }.to raise_error(ArgumentError)
        end
      end
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

    context 'when user does not have access to read one of the agents' do
      let!(:params) do
        super().merge(steps: [{ agent: create(:ai_catalog_agent, public: false) }])
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when flow exceeds maximum steps' do
      before do
        stub_const("#{described_class}::MAX_STEPS", 1)
      end

      let!(:params) do
        super().merge(steps: [{ agent: agent }, { agent: agent }])
      end

      it_behaves_like 'an error response', 'Maximum steps for a flow (1) exceeded'
    end
  end
end
