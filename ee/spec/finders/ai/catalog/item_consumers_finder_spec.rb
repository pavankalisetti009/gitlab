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

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    enable_ai_catalog
  end

  context 'when project_id is provided' do
    let(:params) { { project_id: project.id } }

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

      context 'when user cannot read flows' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
        end

        it { is_expected.to contain_exactly(third_party_flow_consumer) }

        context 'when item_types is [:flow]' do
          let(:params) { super().merge(item_types: [:flow]) }

          it { is_expected.to be_empty }
        end
      end

      context 'when user cannot read third party flows' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
        end

        it { is_expected.to contain_exactly(flow_consumer) }

        context 'when item_types is [:third_party_flow]' do
          let(:params) { super().merge(item_types: [:third_party_flow]) }

          it { is_expected.to be_empty }
        end
      end

      context 'when item_types is empty' do
        let(:params) { super().merge(item_types: []) }

        it { is_expected.to contain_exactly(*project_consumers, flow_consumer, third_party_flow_consumer) }
      end
    end

    context 'when item_types and item_type are provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      let(:params) { super().merge(item_type: :flow, item_types: [:third_party_flow]) }

      it { is_expected.to contain_exactly(flow_consumer, third_party_flow_consumer) }
    end

    context 'when user cannot read flows' do
      let!(:flow) { create(:ai_catalog_flow) }
      let!(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let!(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let!(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
      end

      it { is_expected.to contain_exactly(*project_consumers, third_party_flow_consumer) }
    end

    context 'when user cannot read third party flows' do
      let!(:flow) { create(:ai_catalog_flow) }
      let!(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let!(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let!(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
      end

      it { is_expected.to contain_exactly(*project_consumers, flow_consumer) }
    end

    context 'when include_inherited is true' do
      let(:params) { super().merge(include_inherited: true) }

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

    context 'with a guest user' do
      let_it_be(:guest_user) { create(:user) }
      let(:params) { { project_id: project.id } }

      before_all do
        project.add_guest(guest_user)
      end

      subject(:results) { described_class.new(guest_user, params: params).execute }

      it 'allows guests to read item consumers in the project' do
        expect(results).to match_array(project_consumers)
      end

      context 'when include_inherited is true' do
        let(:params) { super().merge(include_inherited: true) }

        it 'inherits parent consumers' do
          expect(results).to match_array(project_consumers + parent_group_consumers)
        end
      end
    end
  end

  context 'when group_id is provided' do
    let(:params) { { group_id: group.id } }

    it { is_expected.to match_array(group_consumers) }

    context 'when item_id is provided' do
      let(:params) { super().merge(item_id: group_consumers[0].ai_catalog_item_id) }

      it { is_expected.to contain_exactly(group_consumers[0]) }
    end

    context 'when include_inherited is true' do
      let(:params) { super().merge(include_inherited: true) }

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

    context 'with a guest user' do
      let_it_be(:guest_user) { create(:user) }
      let(:params) { { group_id: group.id } }

      before_all do
        group.add_guest(guest_user)
      end

      subject(:results) { described_class.new(guest_user, params: params).execute }

      it 'allows guests to read item consumers in the group' do
        expect(results).to match_array(group_consumers)
      end

      context 'when include_inherited is true' do
        let(:params) { super().merge(include_inherited: true) }

        it 'includes parent consumers' do
          expect(results).to match_array(group_consumers + parent_group_consumers)
        end
      end
    end
  end

  context 'when both project_id and group_id are provided' do
    let(:params) { { project_id: project.id, group_id: group.id } }

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

  context 'when foundational_flow_reference is provided' do
    let(:custom_flow) { create(:ai_catalog_flow) }
    let!(:custom_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: custom_flow) }
    let(:flow_with_ref) { create(:ai_catalog_flow, foundational_flow_reference: 'gitlab/foo_maker') }
    let!(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow_with_ref) }
    let(:params) { { project_id: project.id, foundational_flow_reference: 'gitlab/foo_maker' } }

    it { is_expected.to contain_exactly(flow_consumer) }

    context 'when user is not allowed to read custom flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
      end

      # Custom flows doesn't interfer with foundational flows
      it { is_expected.to contain_exactly(flow_consumer) }
    end

    context 'when user is not allowed to read foundational flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(false)
      end

      it { is_expected.to be_empty }
    end

    context 'when searching for beta foundational flow' do
      let(:beta_flow) { create(:ai_catalog_flow, foundational_flow_reference: 'sast_fp_detection/v1') }
      let!(:beta_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: beta_flow) }
      let(:params) { { project_id: project.id, foundational_flow_reference: 'sast_fp_detection/v1' } }

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: false)
        end

        it 'does not return beta flow consumers' do
          is_expected.to be_empty
        end
      end

      context 'when beta features are enabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: true)
        end

        it 'returns beta flow consumers' do
          is_expected.to contain_exactly(beta_flow_consumer)
        end
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it 'does not return beta flow consumers' do
          is_expected.to be_empty
        end
      end

      context 'when beta features are enabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: true)
        end

        it 'returns beta flow consumers' do
          is_expected.to contain_exactly(beta_flow_consumer)
        end
      end
    end

    context 'when searching for GA foundational flow' do
      let(:ga_flow) { create(:ai_catalog_flow, foundational_flow_reference: 'code_review/v1') }
      let!(:ga_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: ga_flow) }
      let(:params) { { project_id: project.id, foundational_flow_reference: 'code_review/v1' } }

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: false)
        end

        it 'still returns GA flow consumers' do
          is_expected.to contain_exactly(ga_flow_consumer)
        end
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it 'still returns GA flow consumers' do
          is_expected.to contain_exactly(ga_flow_consumer)
        end
      end
    end

    context 'when no items match the reference' do
      let(:params) { { project_id: project.id, foundational_flow_reference: 'nonexistent/reference' } }

      it { is_expected.to be_empty }
    end

    context 'when other project is provided' do
      let(:params) { { project_id: another_project.id, foundational_flow_reference: 'gitlab/foo_maker' } }

      it { is_expected.to be_empty }
    end
  end

  context 'when configurable_for_project_id is provided' do
    let_it_be(:configurable_for_project) { create(:project, group: parent_group) }
    let_it_be(:public_flow_from_other_project) { create(:ai_catalog_flow, public: true, project: project) }

    let_it_be(:private_agent_owned_by_configurable_for_project) do
      create(:ai_catalog_agent, public: false, project: configurable_for_project)
    end

    let_it_be(:public_flow_consumer) do
      create(:ai_catalog_item_consumer, group: parent_group, item: public_flow_from_other_project)
    end

    let_it_be(:private_agent_consumer) do
      create(:ai_catalog_item_consumer, group: parent_group, item: private_agent_owned_by_configurable_for_project)
    end

    let(:params) { { group_id: parent_group.id, configurable_for_project_id: configurable_for_project.id } }

    it { is_expected.to contain_exactly(public_flow_consumer, private_agent_consumer) }

    context 'when configurable project cannot access private items from other projects' do
      let(:params) { { group_id: parent_group.id, configurable_for_project_id: project.id } }

      it { is_expected.to contain_exactly(public_flow_consumer) }
    end

    context 'when item_types is provided' do
      let(:params) { super().merge(item_types: %i[flow]) }

      it { is_expected.to contain_exactly(public_flow_consumer) }
    end
  end

  describe 'ordering' do
    let_it_be(:foundational_flow) { create(:ai_catalog_flow, :with_foundational_flow_reference, :public) }
    let_it_be(:regular_agent_1) { create(:ai_catalog_agent, :public) }
    let_it_be(:regular_agent_2) { create(:ai_catalog_agent, :public) }

    let_it_be(:foundational_flow_consumer) do
      create(:ai_catalog_item_consumer, item: foundational_flow, project: project)
    end

    let_it_be(:regular_agent_1_consumer) do
      create(:ai_catalog_item_consumer, item: regular_agent_1, project: project)
    end

    let_it_be(:regular_agent_2_consumer) do
      create(:ai_catalog_item_consumer, item: regular_agent_2, project: project)
    end

    let(:params) { { project_id: project.id } }

    it 'returns foundational flows first, followed by other consumers' do
      results_array = results.to_a

      remaining_consumers = [
        regular_agent_2_consumer,
        regular_agent_1_consumer,
        *project_consumers
      ]

      expect(results_array.first).to eq(foundational_flow_consumer)
      expect(results_array.last(remaining_consumers.size)).to match_array(remaining_consumers)
    end
  end
end
