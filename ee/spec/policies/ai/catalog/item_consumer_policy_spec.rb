# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :workflow_catalog do
  let(:user) { nil }

  subject(:policy) { described_class.new(user, item_consumer) }

  context 'when item consumer belongs to a project' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project: build_stubbed(:project)) }

    it { is_expected.to delegate_to(::ProjectPolicy) }
  end

  context 'when item consumer belongs to a group' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, group: build_stubbed(:group)) }

    it { is_expected.to delegate_to(::GroupPolicy) }
  end

  describe 'execute_ai_catalog_item' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, developers: user) }
    let_it_be(:item) { create(:ai_catalog_flow, project: project) }
    let_it_be(:item_version) do
      item.latest_version.update!(release_date: Time.now)
    end

    let_it_be_with_reload(:item_consumer) do
      create(:ai_catalog_item_consumer,
        project: project,
        item: item
      )
    end

    let(:flows_available) { false }
    let(:third_party_flows_available) { false }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog_flows).and_return(flows_available)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :foundational_flows).and_return(false)
    end

    context 'when item is flow' do
      context 'when StageCheck :ai_catalog_flows is false' do
        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
      end

      context 'when StageCheck :ai_catalog_flows is true' do
        let(:flows_available) { true }

        it { is_expected.to be_allowed(:execute_ai_catalog_item) }
      end
    end

    context 'when item is third party flow' do
      let(:item) { create(:ai_catalog_third_party_flow) }
      let(:item_consumer) do
        create(:ai_catalog_item_consumer,
          project: project,
          item: item
        )
      end

      before do
        item.latest_version.update!(release_date: Time.now)
      end

      context 'when StageCheck :ai_catalog_third_party_flows is false' do
        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
      end

      context 'when StageCheck :ai_catalog_third_party_flows is true' do
        let(:third_party_flows_available) { true }

        it { is_expected.to be_allowed(:execute_ai_catalog_item) }
      end
    end

    context 'when pinned_version is not executable' do
      let(:flows_available) { true }

      after do
        item_consumer.update!(pinned_version_prefix: nil)
        item_consumer.instance_variable_set(:@pinned_version, nil)
      end

      context 'when pinned_version cannot be resolved' do
        before do
          item_consumer.instance_variable_set(:@pinned_version, nil)
          item_consumer.update!(pinned_version_prefix: non_existing_record_id)
        end

        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
      end

      context 'when pinned_version is in draft state' do
        let(:item_version) do
          create(:ai_catalog_flow_version, :draft, item: item)
        end

        before do
          item_consumer.instance_variable_set(:@pinned_version, nil)
          item_consumer.update!(pinned_version_prefix: item_version.version)
        end

        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
      end
    end

    context 'when item is a beta foundational flow' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project_with_group) { create(:project, group: group, developers: user) }
      let_it_be(:beta_flow) do
        create(:ai_catalog_flow, project: project_with_group, foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let_it_be(:foundational_flows_available) { true }

      let_it_be_with_reload(:beta_item_consumer) do
        create(:ai_catalog_item_consumer,
          project: project_with_group,
          item: beta_flow
        )
      end

      subject(:policy) { described_class.new(user, beta_item_consumer) }

      before do
        beta_flow.latest_version.update!(release_date: Time.now) unless beta_flow.latest_version.release_date
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project_with_group, :ai_catalog).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project_with_group, :foundational_flows).and_return(foundational_flows_available)
      end

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          group.namespace_settings.update!(experiment_features_enabled: false)
        end

        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
        it { is_expected.to be_disallowed(:read_ai_catalog_item_consumer) }
      end

      context 'when beta features are enabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          group.namespace_settings.update!(experiment_features_enabled: true)
        end

        it { is_expected.to be_allowed(:execute_ai_catalog_item) }
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
        it { is_expected.to be_disallowed(:read_ai_catalog_item_consumer) }
      end

      context 'when beta features are enabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: true)
        end

        it { is_expected.to be_allowed(:execute_ai_catalog_item) }
      end
    end

    context 'when item is a GA foundational flow' do
      let_it_be(:ga_group) { create(:group) }
      let_it_be(:ga_project) { create(:project, group: ga_group, developers: user) }
      let_it_be(:ga_flow) do
        create(:ai_catalog_flow, project: ga_project, foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:foundational_flows_available) { true }

      let_it_be_with_reload(:ga_item_consumer) do
        create(:ai_catalog_item_consumer,
          project: ga_project,
          item: ga_flow
        )
      end

      subject(:policy) { described_class.new(user, ga_item_consumer) }

      before do
        ga_flow.latest_version.update!(release_date: Time.now) unless ga_flow.latest_version.release_date
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(ga_project, :ai_catalog).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(ga_project, :foundational_flows).and_return(foundational_flows_available)
      end

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          ga_group.namespace_settings.update!(experiment_features_enabled: false)
        end

        it 'allows execution of GA flows' do
          is_expected.to be_allowed(:execute_ai_catalog_item)
        end
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it 'allows execution of GA flows' do
          is_expected.to be_allowed(:execute_ai_catalog_item)
        end
      end
    end
  end
end
