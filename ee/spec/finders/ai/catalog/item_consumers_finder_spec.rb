# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumersFinder, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group, developers: user) }
  let_it_be(:parent_group_consumers) { create_list(:ai_catalog_item_consumer, 2, group: parent_group) }
  let_it_be(:project) { create(:project, group: parent_group) }
  let_it_be(:project_consumers) { create_list(:ai_catalog_item_consumer, 2, project: project) }
  let_it_be(:another_project) { create(:project, group: parent_group) }
  let_it_be(:another_project_consumer) { create(:ai_catalog_item_consumer, project: another_project) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:group_consumers) { create_list(:ai_catalog_item_consumer, 2, group: group) }

  let(:include_inherited) { false }
  let(:params) { { include_inherited: include_inherited } }

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    enable_ai_catalog
  end

  context 'when project_id is provided' do
    let(:params) { super().merge(project_id: project.id) }

    it { is_expected.to match_array(project_consumers) }

    context 'when item_id is provided' do
      let(:params) { super().merge(item_id: project_consumers[0].ai_catalog_item_id) }

      it { is_expected.to contain_exactly(project_consumers[0]) }
    end

    context 'when item_type is provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }
      let(:params) { super().merge(item_type: :flow) }

      it { is_expected.to contain_exactly(flow_consumer) }
    end

    context 'when item_types is provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      let(:params) { super().merge(item_types: %i[flow third_party_flow]) }

      it { is_expected.to contain_exactly(flow_consumer, third_party_flow_consumer) }
    end

    context 'when item_types and item_type are provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      let(:params) { super().merge(item_type: :flow, item_types: [:third_party_flow]) }

      it { is_expected.to contain_exactly(flow_consumer, third_party_flow_consumer) }
    end

    context 'when include_inherited is true' do
      let(:include_inherited) { true }

      it { is_expected.to match_array(project_consumers + parent_group_consumers) }

      context 'when item_id is also provided' do
        let(:params) { super().merge(item_id: parent_group_consumers[0].ai_catalog_item_id) }

        it { is_expected.to contain_exactly(parent_group_consumers[0]) }
      end

      context 'when item_types is also provided' do
        let(:flow) { create(:ai_catalog_flow) }
        let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }
        let(:parent_flow_consumer) { create(:ai_catalog_item_consumer, group: parent_group, item: flow) }
        let(:params) { super().merge(item_types: [:flow]) }

        it { is_expected.to contain_exactly(flow_consumer, parent_flow_consumer) }
      end
    end

    context 'when project does not exist' do
      let(:params) { super().merge(project_id: non_existing_record_id) }

      it { is_expected.to be_empty }
    end
  end

  context 'when group_id is provided' do
    let(:params) { super().merge(group_id: group.id) }

    it { is_expected.to match_array(group_consumers) }

    context 'when item_id is provided' do
      let(:params) { super().merge(item_id: group_consumers[0].ai_catalog_item_id) }

      it { is_expected.to contain_exactly(group_consumers[0]) }
    end

    context 'when include_inherited is true' do
      let(:include_inherited) { true }

      it { is_expected.to match_array(group_consumers + parent_group_consumers) }

      context 'when item_id is also provided' do
        let(:params) { super().merge(item_id: parent_group_consumers[0].ai_catalog_item_id) }

        it { is_expected.to contain_exactly(parent_group_consumers[0]) }
      end

      context 'when item_types is also provided' do
        let(:flow) { create(:ai_catalog_flow) }
        let(:flow_consumer) { create(:ai_catalog_item_consumer, group: group, item: flow) }
        let(:parent_flow_consumer) { create(:ai_catalog_item_consumer, group: parent_group, item: flow) }
        let(:params) { super().merge(item_types: [:flow]) }

        it { is_expected.to contain_exactly(flow_consumer, parent_flow_consumer) }
      end
    end
  end

  context 'when both project_id and group_id are provided' do
    let(:params) { super().merge(project_id: project.id, group_id: group.id) }

    it 'uses project_id and ignores group_id' do
      expect(results).to match_array(project_consumers)
    end
  end

  context 'when neither project_id or group_id are provided' do
    let(:params) { { item_id: project_consumers[0].ai_catalog_item_id } }

    it 'raises an error' do
      expect { results }.to raise_error(ArgumentError, 'Must provide either project_id or group_id param')
    end
  end
end
