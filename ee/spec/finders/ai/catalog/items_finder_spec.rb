# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemsFinder, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:project_reporter_access) { create(:project, reporters: user) }
  let_it_be(:project_developer_access) { create(:project, developers: user) }

  let_it_be(:public_flow) { create(:ai_catalog_flow, public: true) }
  let_it_be(:public_deleted_flow) { create(:ai_catalog_flow, deleted_at: Time.zone.now) }
  let_it_be(:public_flow_in_other_org) { create(:ai_catalog_flow, public: true, organization: create(:organization)) }
  let_it_be(:private_flow) { create(:ai_catalog_flow, public: false) }
  let_it_be(:public_agent) { create(:ai_catalog_agent, public: true) }

  let_it_be(:private_flow_reporter_access) do
    create(:ai_catalog_flow, public: false, project: project_reporter_access)
  end

  let_it_be(:private_flow_developer_access) do
    create(:ai_catalog_flow, public: false, project: project_developer_access)
  end

  let_it_be(:private_agent_developer_access) do
    create(:ai_catalog_agent, public: false, project: project_developer_access)
  end

  let_it_be(:private_third_party_flow_developer_access) do
    create(:ai_catalog_third_party_flow, public: false, project: project_developer_access)
  end

  let(:params) { { organization: user.organization } }

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    enable_ai_catalog
  end

  it 'returns items visible to user' do
    is_expected.to contain_exactly(
      public_flow,
      private_third_party_flow_developer_access,
      public_agent,
      private_flow_developer_access,
      private_agent_developer_access
    )
  end

  context 'when filtering by item_type' do
    let(:params) { { organization: user.organization, item_type: 'agent' } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_developer_access
      )
    end
  end

  context 'when filtering by item_types' do
    let(:params) { { organization: user.organization, item_types: %w[third_party_flow agent] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_developer_access,
        private_third_party_flow_developer_access
      )
    end
  end

  context 'when filtering by item_type and item_types' do
    let(:params) { { organization: user.organization, item_types: ['third_party_flow'], item_type: 'agent' } }

    it 'returns items matching both arguments' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_developer_access,
        private_third_party_flow_developer_access
      )
    end
  end

  context 'when filtering by search' do
    let_it_be(:agent_with_name_match) { create(:ai_catalog_agent, public: true, name: 'Autotriager') }
    let_it_be(:flow_with_description_match) do
      create(:ai_catalog_flow, public: true, description: 'Flow to triage issues')
    end

    let(:params) { { organization: user.organization, search: 'triage' } }

    it 'returns items that partial match on the name or description' do
      is_expected.to contain_exactly(
        agent_with_name_match,
        flow_with_description_match
      )
    end
  end

  context 'when filtering by organization' do
    context "with user's organization" do
      let(:params) { { organization: user.organization } }

      it 'returns the matching items' do
        is_expected.not_to include(public_flow_in_other_org)
        expect(results.size).to eq(5)
      end
    end

    context "with organization user does not belong to" do
      let(:params) { { organization: public_flow_in_other_org.organization } }

      it 'returns public items in that organization' do
        is_expected.to contain_exactly(public_flow_in_other_org)
      end

      it 'returns the matching items when user is nil' do
        expect(described_class.new(nil, params: params).execute).to contain_exactly(
          public_flow_in_other_org
        )
      end
    end

    context 'when organization and project do not match' do
      let(:params) { { organization: user.organization, project: project_reporter_access } }

      it 'uses the explicit organization parameter and returns no items because organizations do not match' do
        is_expected.to be_empty
      end
    end

    context 'when organization is not provided' do
      let(:params) { {} }

      it 'raises an ArgumentError' do
        expect do
          results
        end.to raise_error(ArgumentError, _('Organization parameter must be specified'))
      end
    end
  end

  context 'when filtering by project' do
    let(:params) { { organization: user.organization, project: [public_flow.project, public_agent.project] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(public_flow, public_agent)
    end
  end

  context 'when filtering by ID' do
    let(:params) { { organization: user.organization, id: [public_flow.id, public_agent.id] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(public_flow, public_agent)
    end
  end

  describe 'ordering' do
    let_it_be(:gitlab_item_1) { create(:ai_catalog_agent, public: true) }
    let_it_be(:regular_item_1) { create(:ai_catalog_agent, public: true) }
    let_it_be(:gitlab_item_2) { create(:ai_catalog_agent, public: true) }
    let_it_be(:regular_item_2) { create(:ai_catalog_agent, public: true) }

    let(:params) { { organization: user.organization } }

    before do
      stub_const('Ai::Catalog::Item::GITLAB_ITEM_IDS', [gitlab_item_1.id, gitlab_item_2.id])
    end

    it 'orders by id desc when not SaaS' do
      is_expected.to eq(
        [
          regular_item_2,
          gitlab_item_2,
          regular_item_1,
          gitlab_item_1,
          private_third_party_flow_developer_access,
          private_agent_developer_access,
          private_flow_developer_access,
          public_agent,
          public_flow
        ]
      )
    end

    context 'when SaaS', :saas do
      it 'sorts GitLab items first, then id desc' do
        is_expected.to eq(
          [
            gitlab_item_1,
            gitlab_item_2,
            regular_item_2,
            regular_item_1,
            private_third_party_flow_developer_access,
            private_agent_developer_access,
            private_flow_developer_access,
            public_agent,
            public_flow
          ]
        )
      end
    end
  end
end
