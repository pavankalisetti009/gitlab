# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumer, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:item).required }

    it { is_expected.to belong_to(:organization).optional }
    it { is_expected.to belong_to(:group).optional }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:service_account).optional }
    it { is_expected.to belong_to(:parent_item_consumer).optional }

    it { is_expected.to have_one(:flow_trigger).optional }

    it { is_expected.to accept_nested_attributes_for(:flow_trigger) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:locked).in_array([true, false]) }

    it { is_expected.to validate_length_of(:pinned_version_prefix).is_at_most(50) }

    it 'uniqueness of service account' do
      group = create(:group)
      service_account = create(:service_account, provisioned_by_group: group)
      item_consumer = create(:ai_catalog_item_consumer, :for_flow, group:, service_account:)

      expect(item_consumer).to validate_uniqueness_of(:service_account).allow_nil
    end

    it 'uniqueness of item for organization' do
      item_consumer = create(:ai_catalog_item_consumer, organization: create(:organization))

      expect(item_consumer).to validate_uniqueness_of(:item).scoped_to(:organization_id)
        .with_message('already configured')
    end

    it 'uniqueness of item for group' do
      item_consumer = create(:ai_catalog_item_consumer, group: create(:group))

      expect(item_consumer).to validate_uniqueness_of(:item).scoped_to(:group_id).with_message('already configured')
    end

    it 'uniqueness of item for project' do
      item_consumer = create(:ai_catalog_item_consumer, project: create(:project))

      expect(item_consumer).to validate_uniqueness_of(:item).scoped_to(:project_id).with_message('already configured')
    end

    context 'when item is an agent' do
      subject(:item) { build(:ai_catalog_item_consumer, :for_agent) }

      it { is_expected.to validate_absence_of(:service_account) }
    end

    context 'when item is a flow' do
      subject(:item) { build(:ai_catalog_item_consumer, :for_flow) }

      it { is_expected.not_to validate_absence_of(:service_account) }
    end

    context 'when item is a third party flow' do
      subject(:item) { build(:ai_catalog_item_consumer, :for_third_party_flow) }

      it { is_expected.not_to validate_absence_of(:service_account) }
    end

    describe '#validate_item_privacy_allowed' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: top_level_group) }
      let_it_be(:project) { create(:project, group: group) }

      context 'when item consumer belongs to project' do
        subject(:item_consumer) { build(:ai_catalog_item_consumer, project: project, item: item) }

        context 'when item is public' do
          let(:item) { create(:ai_catalog_flow, public: true, project: project) }

          it { is_expected.to be_valid }
        end

        context 'when item is private, and belongs to same project as item consumer project' do
          let(:item) { create(:ai_catalog_flow, public: false, project: project) }

          it { is_expected.to be_valid }
        end

        context 'when item is private, and belongs a different project to item consumer' do
          let(:item) { create(:ai_catalog_flow, public: false, project: create(:project)) }

          it 'is invalid' do
            is_expected.not_to be_valid
            expect(item_consumer.errors[:item]).to include('is private to another project')
          end

          context 'when item consumer is not changing its item attribute' do
            before do
              item_consumer.save!(validate: false)
            end

            it { is_expected.to be_valid }
          end
        end
      end

      context 'when item consumer belongs to group' do
        subject(:item_consumer) { build(:ai_catalog_item_consumer, group:, item:) }

        context 'when item is public' do
          let(:item) { create(:ai_catalog_flow, public: true, project: project) }

          it { is_expected.to be_valid }
        end

        context 'when item is private' do
          let(:item) { create(:ai_catalog_flow, public: false, project: project) }

          it { is_expected.not_to be_valid }

          context 'when group is the top-level group of the item project' do
            subject(:item_consumer) { build(:ai_catalog_item_consumer, group: top_level_group, item: item) }

            it { is_expected.to be_valid }
          end
        end
      end
    end

    describe 'item and item_consumer organization checks' do
      let_it_be(:default_organization) { create(:organization) }
      let_it_be(:different_organization) { create(:organization) }

      let_it_be(:project_with_different_org) { build(:project, organization: different_organization) }
      let_it_be(:group_with_different_org) { build(:group, organization: different_organization) }

      let_it_be(:project_with_default_org) { build(:project, organization: default_organization) }
      let_it_be(:group_with_default_org) { build(:group, organization: default_organization) }

      let_it_be(:item) { create(:ai_catalog_item, organization: default_organization) }

      where(:organization, :project, :group, :expected_validity) do
        [
          [ref(:default_organization), nil, nil, true],
          [nil, ref(:project_with_default_org), nil, true],
          [nil, nil, ref(:group_with_default_org), true],
          [ref(:different_organization), nil, nil, false],
          [nil, ref(:project_with_different_org), nil, false],
          [nil, nil, ref(:group_with_different_org), false]
        ]
      end

      with_them do
        subject(:item_consumer) { build(:ai_catalog_item_consumer, organization:, group:, project:, item:) }

        it 'validates they belong to the same organization' do
          expect(item_consumer.valid?).to eq(expected_validity)

          unless expected_validity
            expect(item_consumer.errors[:item]).to include("organization must match the item consumer's organization")
          end
        end
      end
    end

    describe '#validate_exactly_one_sharding_key_present' do
      let(:organization_stub) { build_stubbed(:organization) }
      let(:group_stub) { build_stubbed(:group) }
      let(:project_stub) { build_stubbed(:project) }

      where(:case_name, :organization, :group, :project, :expected_validity) do
        [
          ['only organization', ref(:organization_stub), nil, nil, true],
          ['only group', nil, ref(:group_stub), nil, true],
          ['only project', nil, nil, ref(:project_stub), true],
          ['organization and group', ref(:organization_stub), ref(:group_stub), nil, false],
          ['organization and project', ref(:organization_stub), nil, ref(:project_stub), false],
          ['group and project', nil, ref(:group_stub), ref(:project_stub), false],
          ['all three', ref(:organization_stub), ref(:group_stub), ref(:project_stub), false],
          ['none', nil, nil, nil, false]
        ]
      end

      with_them do
        it "validates correctly for #{params[:case_name]}" do
          setting = build(:ai_catalog_item_consumer,
            item: build_stubbed(:ai_catalog_item, organization:),
            organization: organization,
            group: group,
            project: project
          )

          expect(setting.valid?).to eq(expected_validity)

          if expected_validity
            expect(setting.errors[:base]).to be_empty
          else
            expect(setting.errors[:base]).to include(
              'The item consumer must belong to only one organization, group, or project'
            )

            expect(setting.errors.full_messages)
              .to include('The item consumer must belong to only one organization, group, or project')
          end
        end
      end
    end

    describe '#validate_service_account' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:parent_group) { create(:group, parent: top_level_group) }
      let_it_be(:service_account) { create(:user, :service_account) }
      let_it_be(:project) { create(:project, namespace: parent_group, developers: service_account) }
      let_it_be(:item) { create(:ai_catalog_flow, project: project, public: true) }
      let_it_be(:user_detail) { create(:user_detail, user: service_account, provisioned_by_group: top_level_group) }

      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_group_service_account) { create(:user, :service_account) }
      let_it_be(:other_group_service_account_user_detail) do
        create(:user_detail, user: other_group_service_account, provisioned_by_group: other_group)
      end

      subject(:item_consumer) do
        build(:ai_catalog_item_consumer, group: top_level_group, item: item, service_account: service_account)
      end

      it { is_expected.to be_valid }

      context "when item consumer belongs to a group which isn't a top level group" do
        let_it_be(:group) { create(:group, parent: top_level_group, developers: service_account) }

        subject(:item_consumer) do
          build(:ai_catalog_item_consumer, group:, item:, service_account:)
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:service_account])
            .to include("can be set only for top-level group consumers")
        end
      end

      context 'when service account is not provided' do
        subject(:item_consumer) { build(:ai_catalog_item_consumer, project: project, item: item, service_account: nil) }

        it { is_expected.to be_valid }
      end

      context 'when account is not a service account' do
        let_it_be(:regular_user) { create(:user) }

        subject(:item_consumer) do
          build(:ai_catalog_item_consumer, group: top_level_group, item: item, service_account: regular_user)
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:service_account]).to include('must be a service account')
        end
      end

      context 'when service account belongs to a different top-level group' do
        subject(:item_consumer) do
          build(
            :ai_catalog_item_consumer,
            group: top_level_group,
            item: item,
            service_account: other_group_service_account
          )
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:service_account])
            .to include('must be provisioned by the group')
        end
      end
    end

    describe '#validate_parent_item_consumer' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:parent_group) { create(:group, parent: top_level_group) }
      let_it_be(:project) { create(:project, group: parent_group) }
      let_it_be(:item) { create(:ai_catalog_item, :flow, public: true) }
      let_it_be(:parent_item_consumer) do
        create(:ai_catalog_item_consumer, group: top_level_group, item: item)
      end

      let_it_be(:item_consumer_for_other_project) do
        create(:ai_catalog_item_consumer, project: create(:project), item: item)
      end

      let_it_be(:other_top_level_group) { create(:group) }
      let_it_be(:other_top_level_group_item_consumer) do
        create(:ai_catalog_item_consumer, group: other_top_level_group, item: item)
      end

      let_it_be(:parent_group_item_consumer) do
        create(:ai_catalog_item_consumer, group: parent_group, item: item)
      end

      let_it_be(:service_account) { create(:service_account) }

      subject(:item_consumer) { build(:ai_catalog_item_consumer, project:, item:, parent_item_consumer:) }

      it { is_expected.to be_valid }

      context 'when parent item consumer belongs to a different top-level group' do
        subject(:item_consumer) do
          build(
            :ai_catalog_item_consumer,
            project: project,
            item: item,
            parent_item_consumer: other_top_level_group_item_consumer
          )
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:parent_item_consumer])
            .to include("must belong to this project's top-level group")
        end
      end

      context 'when parent item consumer belongs to a group which is not a top-level group' do
        subject(:item_consumer) do
          build(
            :ai_catalog_item_consumer,
            project: project,
            item: item,
            parent_item_consumer: parent_group_item_consumer
          )
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:parent_item_consumer])
            .to include("must belong to this project's top-level group")
        end
      end

      context 'when parent item consumer does not belong to a group' do
        subject(:item_consumer) do
          build(
            :ai_catalog_item_consumer,
            project: project,
            item: item,
            parent_item_consumer: item_consumer_for_other_project
          )
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:parent_item_consumer])
            .to include("must belong to this project's top-level group")
        end
      end

      context 'when item consumer belongs to a group' do
        subject(:item_consumer) do
          build(:ai_catalog_item_consumer, group: parent_group, item: item, parent_item_consumer: parent_item_consumer)
        end

        it 'is invalid' do
          is_expected.not_to be_valid
          expect(item_consumer.errors[:parent_item_consumer])
            .to include('can be set only for project consumers')
        end
      end
    end
  end

  describe '.exists_for_service_account_and_project_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }

    let_it_be(:project_with_consumer) { create(:project, namespace: group, developers: service_account) }
    let_it_be(:project_without_consumer_for_flow) { create(:project, namespace: group, developers: service_account) }

    let_it_be(:parent_item_consumer) { create(:ai_catalog_item_consumer, :for_flow, group:, service_account:) }

    let_it_be(:child_item_consumer) do
      create(
        :ai_catalog_item_consumer, :for_flow, project: project_with_consumer, parent_item_consumer: parent_item_consumer
      )
    end

    let_it_be(:unrelated_item_consumer) do
      create(:ai_catalog_item_consumer, :for_flow, project: project_without_consumer_for_flow)
    end

    let_it_be(:project_item_consumer_with_no_parent) do
      create(:ai_catalog_item_consumer, project: project_without_consumer_for_flow, parent_item_consumer: nil)
    end

    let(:project_id) { project_with_consumer.id }

    subject(:exists_for_service_account_and_project_id) do
      described_class.exists_for_service_account_and_project_id?(service_account, project_id)
    end

    context 'when a consumer exists for the project' do
      it { is_expected.to be(true) }
    end

    context 'when a consumer does not exist for the project' do
      let(:project_id) { project_without_consumer_for_flow.id }

      it { is_expected.to be(false) }
    end

    context 'when the service account is nil' do
      let(:service_account) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the project_id is nil' do
      let_it_be(:project_id) { nil }

      it { is_expected.to be(false) }
    end

    context 'when there is no parent item consumer' do
      let_it_be(:service_account) { create(:service_account) }

      it { is_expected.to be(false) }
    end
  end

  describe '#pinned_version' do
    let_it_be(:project) { create(:project) }
    let_it_be(:item) { create(:ai_catalog_flow, project: project) }

    let(:item_consumer) { create(:ai_catalog_item_consumer, item: item, project: project) }

    context 'when pinned_version_prefix is nil' do
      it 'returns the latest version' do
        expect(item_consumer.pinned_version).to eq(item.latest_version)
      end
    end

    context 'when pinned_version_prefix is set' do
      let_it_be(:version) { create(:ai_catalog_flow_version, item: item, version: '2.5.0') }

      before do
        item_consumer.update!(pinned_version_prefix: '2')
      end

      it 'returns the resolved version' do
        expect(item_consumer.pinned_version).to eq(version)
      end
    end

    it 'is memoized' do
      first_result, second_result = nil

      first_call = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        first_result = item_consumer.pinned_version
      end

      second_call = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        second_result = item_consumer.pinned_version
      end

      expect(first_call.count).to be > 0
      expect(second_call.count).to eq(0)
      expect(first_result).to eq(second_result)
    end
  end

  describe '.for_service_account' do
    let_it_be(:group) { create(:group) }
    let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }
    let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, :for_flow, group:, service_account:) }

    subject(:for_service_account) { described_class.for_service_account(service_account.id) }

    it 'returns the consumer with the given service account' do
      expect(for_service_account).to contain_exactly(item_consumer)
    end

    context 'when the service account is not in use' do
      let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }

      it { is_expected.to be_empty }
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      it 'includes records that belong to the given projects' do
        included_projects = create_list(:project, 2)
        included_item_consumers = included_projects.map do |project|
          create(:ai_catalog_item_consumer, project: project)
        end

        create(:ai_catalog_item_consumer, project: create(:project))

        expect(described_class.for_projects(included_projects)).to match_array(
          included_item_consumers
        )
      end
    end

    describe '.for_groups' do
      it 'includes records that belong to the given groups' do
        included_groups = create_list(:group, 2)
        included_item_consumers = included_groups.map do |group|
          create(:ai_catalog_item_consumer, group: group)
        end

        create(:ai_catalog_item_consumer, group: create(:group))

        expect(described_class.for_groups(included_groups)).to match_array(
          included_item_consumers
        )
      end
    end

    describe '.for_container_item_pairs' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }
      let_it_be(:item1) { create(:ai_catalog_item) }
      let_it_be(:item2) { create(:ai_catalog_item) }
      let_it_be(:group_item1_consumer) { create(:ai_catalog_item_consumer, group: group, item: item1) }
      let_it_be(:project1_item1_consumer) { create(:ai_catalog_item_consumer, project: project1, item: item1) }
      let_it_be(:project1_item2_consumer) { create(:ai_catalog_item_consumer, project: project1, item: item2) }
      let_it_be(:project2_item1_consumer) { create(:ai_catalog_item_consumer, project: project2, item: item1) }

      context 'for groups' do
        it 'returns consumers matching the group-item pairs' do
          expect(described_class.for_container_item_pairs(:group, [[group.id, item1.id]])).to contain_exactly(
            group_item1_consumer
          )
        end
      end

      context 'for projects' do
        it 'returns consumers matching the project-item pairs' do
          container_item_pairs = [
            [project1.id, item1.id],
            [project1.id, item2.id]
          ]

          expect(described_class.for_container_item_pairs(:project, container_item_pairs)).to contain_exactly(
            project1_item1_consumer,
            project1_item2_consumer
          )
        end
      end

      context 'with non-existent pairs' do
        it 'returns empty result' do
          expect(described_class.for_container_item_pairs(:group,
            [[non_existing_record_id, non_existing_record_id]])).to be_empty
        end
      end

      context 'with unknown container type' do
        it 'raises an error' do
          expect { described_class.for_container_item_pairs(:invalid, [[1, 1]]) }
            .to raise_error(ArgumentError)
        end
      end
    end

    describe '.not_for_projects' do
      it 'excludes records that belong to the given projects' do
        excluded_projects = create_list(:project, 2)
        excluded_projects.each { |project| create(:ai_catalog_item_consumer, project: project) }
        included_item_consumers = create_list(:ai_catalog_item_consumer, 2, project: create(:project))

        expect(described_class.not_for_projects(excluded_projects)).to match_array(
          included_item_consumers
        )
      end
    end

    describe '.for_item' do
      it 'filters records by the given item id' do
        project = create(:project)
        item_consumers = create_list(:ai_catalog_item_consumer, 2, project: project)

        expect(described_class.for_item(item_consumers[0].ai_catalog_item_id)).to contain_exactly(item_consumers[0])
      end
    end

    describe '.with_item_type' do
      it 'only includes items with the matching type' do
        project = create(:project)
        flow = create(:ai_catalog_flow)
        agent = create(:ai_catalog_agent)
        flow_consumer = create(:ai_catalog_item_consumer, project: project, item: flow)
        agent_consumer = create(:ai_catalog_item_consumer, project: project, item: agent)

        expect(described_class.with_item_type(:flow)).to contain_exactly(flow_consumer)
        expect(described_class.with_item_type(:agent)).to contain_exactly(agent_consumer)
      end
    end

    describe '.with_items' do
      it 'preloads the item association' do
        project = create(:project)
        create(:ai_catalog_item_consumer, project: project)

        consumers = described_class.with_items

        expect(consumers.first.association(:item)).to be_loaded
      end
    end

    describe '.for_catalog_items' do
      it 'filters records by the given item ids' do
        project = create(:project)
        item1 = create(:ai_catalog_item)
        item2 = create(:ai_catalog_item)
        item3 = create(:ai_catalog_item)

        consumer1 = create(:ai_catalog_item_consumer, project: project, item: item1)
        consumer2 = create(:ai_catalog_item_consumer, project: project, item: item2)
        create(:ai_catalog_item_consumer, project: project, item: item3) # not included

        expect(described_class.for_catalog_items([item1.id, item2.id])).to contain_exactly(consumer1, consumer2)
      end

      it 'returns empty when given empty array' do
        create(:ai_catalog_item_consumer, project: create(:project))

        expect(described_class.for_catalog_items([])).to be_empty
      end
    end

    describe '.with_items_configurable_for_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:other_project) { create(:project) }

      let_it_be(:public_item) { create(:ai_catalog_item, public: true, project: other_project) }
      let_it_be(:private_item_for_project) { create(:ai_catalog_item, public: false, project: project) }
      let_it_be(:private_item_for_other_project) { create(:ai_catalog_item, public: false, project: other_project) }

      let_it_be(:public_item_consumer) { create(:ai_catalog_item_consumer, item: public_item, project: other_project) }
      let_it_be(:private_item_consumer_for_project) do
        create(:ai_catalog_item_consumer, item: private_item_for_project, project: project)
      end

      let_it_be(:private_item_consumer_for_other_project) do
        create(:ai_catalog_item_consumer, item: private_item_for_other_project, project: other_project)
      end

      it 'returns consumers with public items and items belonging to the given project' do
        expect(described_class.with_items_configurable_for_project(project.id)).to contain_exactly(
          public_item_consumer, private_item_consumer_for_project
        )
      end
    end

    describe '.order_by_catalog_priority' do
      let_it_be(:project) { create(:project) }
      let_it_be(:foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:regular_item_1) { create(:ai_catalog_item, :public) }
      let_it_be(:regular_item_2) { create(:ai_catalog_item, :public) }

      let_it_be(:foundational_flow_consumer) do
        create(:ai_catalog_item_consumer, item: foundational_flow, project: project)
      end

      let_it_be(:regular_item_1_consumer) do
        create(:ai_catalog_item_consumer, item: regular_item_1, project: project)
      end

      let_it_be(:regular_item_2_consumer) do
        create(:ai_catalog_item_consumer, item: regular_item_2, project: project)
      end

      subject(:ordered_consumers) { described_class.order_by_catalog_priority }

      it 'returns foundational flows first, followed by other consumers' do
        result = ordered_consumers.to_a

        expect(result.first).to eq(foundational_flow_consumer)
        expect(result.last(2)).to match_array(
          [regular_item_1_consumer, regular_item_2_consumer]
        )
      end
    end
  end
end
