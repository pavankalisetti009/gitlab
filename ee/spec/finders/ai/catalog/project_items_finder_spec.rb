# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ProjectItemsFinder, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:public_flow) { create(:ai_catalog_flow, :public, project: project) }
  let_it_be(:private_agent) { create(:ai_catalog_agent, :private, project: project) }
  let_it_be(:deleted_flow) { create(:ai_catalog_flow, :soft_deleted, project: project) }
  let_it_be(:private_flow_of_other_project) { create(:ai_catalog_flow, :private, project: other_project) }
  let_it_be(:public_flow_of_other_project) { create(:ai_catalog_flow, :public, project: other_project) }
  let_it_be(:public_flow_of_other_org) { create(:ai_catalog_flow, :public, organization: create(:organization)) }
  let_it_be(:deleted_public_flow_of_other_project) do
    create(:ai_catalog_flow, :public, :soft_deleted, project: other_project)
  end

  let(:params) { {} }

  subject(:results) { described_class.new(user, project, params: params).execute }

  before do
    enable_ai_catalog
  end

  it 'returns items that are not deleted and belong to the project' do
    is_expected.to contain_exactly(public_flow, private_agent)
  end

  it 'returns items ordered by id desc' do
    is_expected.to eq([private_agent, public_flow])
  end

  context 'when user does not have permission to read the project' do
    let_it_be(:user) { create(:user) }

    it 'returns no items' do
      is_expected.to be_empty
    end
  end

  context 'when the `global_ai_catalog` flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns no items' do
      is_expected.to be_empty
    end
  end

  context 'when filtering by `item_types`' do
    let(:params) { { item_types: ['agent'] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(private_agent)
    end
  end

  context 'when filtering by `search`' do
    let_it_be(:agent_with_name_match) { create(:ai_catalog_agent, name: 'Autotriager', project: project) }
    let_it_be(:flow_with_description_match) do
      create(:ai_catalog_flow, project: project, description: 'Flow to triage issues')
    end

    let(:params) { { search: 'triage' } }

    it 'returns items that partial match on the name or description' do
      is_expected.to contain_exactly(
        agent_with_name_match,
        flow_with_description_match
      )
    end
  end

  context 'when `all_available` param is `true`' do
    let(:params) { { all_available: true } }

    it 'also returns public items of other projects within the same organization' do
      is_expected.to contain_exactly(public_flow, private_agent, public_flow_of_other_project)
    end
  end

  context 'when filtering by `enabled`' do
    let(:params) { { enabled: enabled } }

    before_all do
      create(:ai_catalog_item_consumer, item: private_agent, project: project)
      create(:ai_catalog_item_consumer, item: public_flow, project: other_project)
      create(:ai_catalog_item_consumer, item: public_flow_of_other_project, project: other_project)
    end

    context 'when `enabled` is `true`' do
      let(:enabled) { true }

      it 'returns items owned by the project and enabled for the project' do
        is_expected.to contain_exactly(private_agent)
      end
    end

    context 'when `enabled` is `false`' do
      let(:enabled) { false }

      it 'returns only items that have not been enabled for the project' do
        is_expected.to contain_exactly(public_flow)
      end
    end
  end
end
