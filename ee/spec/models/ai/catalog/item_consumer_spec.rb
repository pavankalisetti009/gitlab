# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumer, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:item).required }

    it { is_expected.to belong_to(:organization).optional }
    it { is_expected.to belong_to(:group).optional }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:service_account).optional }

    it { is_expected.to have_one(:flow_trigger).optional }

    it { is_expected.to accept_nested_attributes_for(:flow_trigger) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:locked).in_array([true, false]) }

    it { is_expected.to validate_length_of(:pinned_version_prefix).is_at_most(50) }

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
      it { is_expected.to validate_absence_of(:parent_item_consumer) }
    end

    context 'when item is a flow' do
      subject(:item) { build(:ai_catalog_item_consumer, :for_flow) }

      it { is_expected.not_to validate_absence_of(:service_account) }
      it { is_expected.not_to validate_absence_of(:parent_item_consumer) }
    end

    context 'when item is a third party flow' do
      subject(:item) { build(:ai_catalog_item_consumer, :for_third_party_flow) }

      it { is_expected.not_to validate_absence_of(:service_account) }
      it { is_expected.not_to validate_absence_of(:parent_item_consumer) }
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
        subject(:item_consumer) { build(:ai_catalog_item_consumer, group: top_level_group, item: item) }

        context 'when item is public' do
          let(:item) { create(:ai_catalog_flow, public: true, project: project) }

          it { is_expected.to be_valid }
        end

        context 'when item is private' do
          let(:item) { create(:ai_catalog_flow, public: false, project: project) }

          it { is_expected.not_to be_valid }
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
  end
end
