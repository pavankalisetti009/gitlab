# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Item, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:latest_version).required }
    it { is_expected.to belong_to(:latest_released_version) }

    it { is_expected.to have_many(:versions) }
    it { is_expected.to have_many(:consumers) }
    it { is_expected.to have_many(:dependents) }
  end

  describe 'validations' do
    it { expect(build(:ai_catalog_item)).to be_valid }

    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:latest_version) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:verification_level) }

    it { is_expected.to validate_length_of(:name).is_at_least(3).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1_024) }

    describe 'project belongs to same organization' do
      let_it_be(:default_organization) { create(:organization) }
      let_it_be(:different_organization) { create(:organization) }

      let_it_be(:project_with_default_organization) { create(:project, organization: default_organization) }
      let_it_be(:project_with_different_organization) { create(:project, organization: different_organization) }

      where(:project, :expected_validity) do
        [
          [ref(:project_with_default_organization), true],
          [nil, true],
          [ref(:project_with_different_organization), false]
        ]
      end

      with_them do
        subject(:item) { build(:ai_catalog_item, organization: default_organization, project: project) }

        it 'validates the project belongs to the same organization if present' do
          expect(item.valid?).to eq(expected_validity)

          unless expected_validity
            expect(item.errors[:project]).to include("organization must match the item's organization")
          end
        end
      end
    end

    describe 'changing from public to private' do
      let_it_be(:project) { create(:project) }
      let_it_be_with_refind(:item) { create(:ai_catalog_item, public: true, project: project) }

      before do
        item.public = false
      end

      it 'can be changed from public to private' do
        expect(item).to be_valid
      end

      context 'when the project itself is the only consumer' do
        before_all do
          create(:ai_catalog_item_consumer, item: item, project: project)
        end

        it 'can be changed from public to private' do
          expect(item).to be_valid
        end

        context 'when there are other consumers' do
          before_all do
            create(:ai_catalog_item_consumer, item: item, project: create(:project))
          end

          it 'cannot be changed from public to private' do
            expect(item).not_to be_valid
            expect(item.errors[:public]).to include(
              'cannot be changed from public to private as it has catalog consumers'
            )
          end

          context 'when item is not associated with a project' do
            before do
              item.project = nil
            end

            it 'can be changed from private to public' do
              expect(item).to be_valid
            end
          end

          context 'when item was private' do
            let_it_be_with_refind(:item) { create(:ai_catalog_item, public: false, project: project) }

            it 'can be changed from private to public' do
              expect(item).to be_valid
            end
          end
        end
      end

      context 'when the agent is used by other flows' do
        let(:flow_item) { create(:ai_catalog_flow, project: project) }
        let(:agent) { create(:ai_catalog_agent, public: true, project: project) }
        let(:agent_definition) do
          {
            'system_prompt' => 'Talk like a pirate!',
            'user_prompt' => 'What is a leap year?',
            'tools' => []
          }
        end

        let(:agent_v) do
          create(:ai_catalog_agent_version, item: agent, definition: agent_definition, version: '1.0.0')
        end

        let(:flow_definition) do
          {
            'triggers' => [1],
            'steps' => [
              { 'agent_id' => agent.id, 'current_version_id' => agent_v.id, 'pinned_version_prefix' => nil }
            ]
          }
        end

        let(:flow_version) do
          create(:ai_catalog_agent_referenced_flow_version, item: flow_item, definition: flow_definition,
            version: '1.0.0')
        end

        before do
          create(:ai_catalog_item_version_dependency, ai_catalog_item_version: flow_version, dependency: agent)
        end

        it 'cannot be changed from public to private' do
          agent.public = false
          expect(agent).not_to be_valid
          expect(agent.errors[:public]).to include(
            'cannot be changed from public to private as it is used by other flows'
          )
        end

        context 'when item enabled for other projects' do
          before do
            create(:ai_catalog_item_consumer, item: agent, project: create(:project))
          end

          it 'cannot be changed from public to private' do
            agent.public = false
            expect(agent).not_to be_valid
            expect(agent.errors[:public]).to include(
              'cannot be changed from public to private as it is used by other flows',
              'cannot be changed from public to private as it has catalog consumers'
            )
          end
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:item_type).with_values(agent: 1, flow: 2, third_party_flow: 3) }

    it 'defines verification_level enum with namespace verification levels' do
      is_expected.to define_enum_for(:verification_level).with_values(
        ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS
      )
    end
  end

  describe 'scopes' do
    describe '.for_verification_level' do
      ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS.each_key do |level|
        it "returns items with #{level} verification level" do
          expected_item = create(:ai_catalog_item, verification_level: level)

          expect(described_class.for_verification_level(level))
            .to contain_exactly(expected_item)
        end
      end

      it 'returns multiple items with the same verification level' do
        gitlab_maintained_items = create_list(:ai_catalog_item, 2, verification_level: :gitlab_maintained)

        expect(described_class.for_verification_level(:gitlab_maintained))
          .to match_array(gitlab_maintained_items)
      end
    end

    describe '.in_organization' do
      let_it_be(:item_1) { create(:ai_catalog_item, organization: create(:organization)) }
      let_it_be(:item_2) { create(:ai_catalog_item, organization: create(:organization)) }

      it 'returns items for the specified organization' do
        expect(described_class.in_organization(item_1.organization)).to contain_exactly(item_1)
      end
    end

    describe '.not_deleted' do
      let_it_be(:items) { create_list(:ai_catalog_item, 2) }
      let_it_be(:deleted_items) { create_list(:ai_catalog_item, 2, deleted_at: 1.day.ago) }

      it 'returns not deleted items' do
        expect(described_class.not_deleted).to match_array(items)
      end
    end

    describe '.public_only' do
      let_it_be(:public_item) { create(:ai_catalog_item, public: true) }
      let_it_be(:private_item) { create(:ai_catalog_item, public: false) }

      it 'returns the public items' do
        expect(described_class.public_only).to contain_exactly(public_item)
      end
    end

    describe '.public_or_visible_to_user' do
      let_it_be(:user) { create(:user) }

      let_it_be(:reporter_project) { create(:project, reporters: user) }
      let_it_be(:developer_project) { create(:project, developers: user) }

      let_it_be(:public_item) { create(:ai_catalog_item, public: true) }
      let_it_be(:private_item) { create(:ai_catalog_item, public: false) }

      let_it_be(:private_item_in_reporter_project) do
        create(:ai_catalog_item, public: false, project: reporter_project)
      end

      let_it_be(:private_item_in_developer_project) do
        create(:ai_catalog_item, public: false, project: developer_project)
      end

      it 'returns only public items when user is nil' do
        expect(described_class.public_or_visible_to_user(nil)).to contain_exactly(
          public_item
        )
      end

      it 'returns public items, and items belonging to projects user is developer+ of' do
        expect(described_class.public_or_visible_to_user(user)).to contain_exactly(
          public_item,
          private_item_in_developer_project
        )
      end
    end

    describe '.search' do
      let_it_be(:issue_label_agent) { create(:ai_catalog_agent, name: 'Autotriager') }
      let_it_be(:mr_review_flow) { create(:ai_catalog_flow, description: 'Merge request reviewer') }

      it 'finds items by partial name' do
        expect(described_class.search('triage')).to contain_exactly(issue_label_agent)
      end

      it 'finds items by partial description' do
        expect(described_class.search('review')).to contain_exactly(mr_review_flow)
      end
    end

    describe '.with_item_type' do
      let_it_be(:agent_type_item) { create(:ai_catalog_item, item_type: :agent, public: true) }
      let_it_be(:flow_type_item) { create(:ai_catalog_item, item_type: :flow, public: true) }

      it 'returns items of the specified item type' do
        result = described_class.with_item_type(described_class::AGENT_TYPE)

        expect(described_class.count).to eq(2)
        expect(result).to contain_exactly(agent_type_item)
      end
    end

    describe '.foundational_chat_agent_ids' do
      it 'returns empty array when not on SaaS' do
        stub_saas_features(gitlab_duo_saas_only: false)

        expect(described_class.foundational_chat_agent_ids).to eq([])
      end

      context 'when on SaaS', :saas do
        it 'returns global_catalog_ids from foundational chat agents' do
          ids = described_class.foundational_chat_agent_ids

          expected_ids = ::Ai::FoundationalChatAgent.all.filter_map(&:global_catalog_id)
          expect(ids).to match_array(expected_ids)
          expect(ids).not_to include(nil)
        end
      end
    end

    describe '.foundational_flow_ids' do
      let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, public: true) }
      let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, public: true) }
      let_it_be(:non_foundational) { create(:ai_catalog_item, public: true) }

      it 'returns IDs of foundational flows' do
        ids = described_class.foundational_flow_ids

        expect(ids).to match_array([flow1.id, flow2.id])
      end

      it 'limits results to FOUNDATIONAL_FLOWS_LIMIT' do
        create(:ai_catalog_item, :with_foundational_flow_reference, public: true) # 3rd flow

        stub_const("#{described_class}::FOUNDATIONAL_FLOWS_LIMIT", 2)

        ids = described_class.foundational_flow_ids

        expect(ids.count).to eq(2)
        expect(ids).to all(be_in([flow1.id, flow2.id]))
      end
    end

    describe '.foundational_flow_ids_for_references' do
      let_it_be(:code_review_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:sast_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns a hash mapping references to IDs' do
        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'sast_fp_detection/v1'])

        expect(result).to eq({
          'code_review/v1' => code_review_flow.id,
          'sast_fp_detection/v1' => sast_flow.id
        })
      end

      it 'returns empty hash for blank references' do
        expect(described_class.foundational_flow_ids_for_references([])).to eq({})
        expect(described_class.foundational_flow_ids_for_references(nil)).to eq({})
      end

      it 'only returns matching references' do
        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'nonexistent/v1'])

        expect(result).to eq({ 'code_review/v1' => code_review_flow.id })
      end

      it 'respects FOUNDATIONAL_FLOWS_LIMIT' do
        stub_const("#{described_class}::FOUNDATIONAL_FLOWS_LIMIT", 1)

        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'sast_fp_detection/v1'])

        expect(result.size).to eq(1)
      end
    end

    describe '.foundational_flows' do
      let_it_be(:item_with_reference) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns only items with foundational_flow_reference' do
        expect(described_class.foundational_flows).to contain_exactly(item_with_reference)
      end

      it 'excludes items without foundational_flow_reference' do
        expect(described_class.foundational_flows).not_to include(item_without_reference)
      end
    end

    describe '.with_foundational_flow_reference' do
      let_it_be(:code_review_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:sast_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns item with matching foundational_flow_reference' do
        result = described_class.with_foundational_flow_reference('code_review/v1')

        expect(result).to contain_exactly(code_review_flow)
      end

      it 'returns empty relation when no match found' do
        result = described_class.with_foundational_flow_reference('nonexistent/v1')

        expect(result).to be_empty
      end

      it 'does not return items without foundational_flow_reference' do
        result = described_class.with_foundational_flow_reference('code_review/v1')

        expect(result).not_to include(item_without_reference)
      end
    end

    describe '.without_consumers' do
      let_it_be(:project) { create(:project) }
      let_it_be(:item_with_consumers) { create(:ai_catalog_item, :public, project: project) }
      let_it_be(:item_without_consumers) { create(:ai_catalog_item, :public, project: project) }
      let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project, item: item_with_consumers) }

      it 'returns only items without any consumers' do
        expect(described_class.without_consumers).to contain_exactly(item_without_consumers)
      end

      context 'when an item has multiple consumers' do
        let_it_be(:another_consumer) do
          create(:ai_catalog_item_consumer, project: create(:project), item: item_with_consumers)
        end

        it 'still excludes the item' do
          expect(described_class.without_consumers).to contain_exactly(item_without_consumers)
        end
      end

      context 'when all items have consumers' do
        before do
          create(:ai_catalog_item_consumer, project: project, item: item_without_consumers)
        end

        it 'returns an empty collection' do
          expect(described_class.without_consumers).to be_empty
        end
      end
    end

    describe '.order_by_catalog_priority' do
      let_it_be(:foundational_agent) do
        create(:ai_catalog_agent, id: ::Ai::FoundationalChatAgentsDefinitions::ITEMS[1][:global_catalog_id])
      end

      let_it_be(:foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:regular_item_1) { create(:ai_catalog_item) }
      let_it_be(:regular_item_2) { create(:ai_catalog_item) }

      subject(:ordered_items) { described_class.order_by_catalog_priority }

      it 'returns foundational flows first, followed by other items' do
        result = ordered_items.to_a

        expect(result.first).to eq(foundational_flow)
        expect(result.last(3)).to match_array([regular_item_1, regular_item_2, foundational_agent])
      end

      context 'when on SaaS', :saas do
        it 'returns foundational items first, then regular items' do
          result = ordered_items.to_a

          expect(result[0]).to eq(foundational_agent)
          expect(result[1]).to eq(foundational_flow)
          expect(result.last(2)).to match_array([regular_item_1, regular_item_2])
        end
      end
    end
  end

  describe 'callbacks' do
    describe '.prevent_deletion_if_consumers_exist' do
      let_it_be(:item) { create(:ai_catalog_item, deleted_at: 1.day.ago) }

      it 'allows deletion if no consumers exist' do
        expect(item.destroy).to be_truthy
        expect { item.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'when consumers exist' do
        before do
          allow(item).to receive(:consumers).and_return([build_stubbed(:ai_catalog_item_consumer, item: item)])
        end

        it 'prevents deletion' do
          expect(item.destroy).to be(false)
          expect(item.errors[:base]).to contain_exactly('Cannot delete an item that has consumers')
          expect { item.reload }.not_to raise_error
        end
      end
    end
  end

  describe '#deleted?' do
    let(:item) { build_stubbed(:ai_catalog_item, deleted_at: deleted_at) }

    context 'when deleted_at is not nil' do
      let(:deleted_at) { 1.day.ago }

      it 'returns true' do
        expect(item).to be_deleted
      end
    end

    context 'when deleted_at is nil' do
      let(:deleted_at) { nil }

      it 'returns false' do
        expect(item).not_to be_deleted
      end
    end
  end

  describe '#private?' do
    let(:item) { build_stubbed(:ai_catalog_item, public: is_public) }

    context 'when item is private' do
      let(:is_public) { false }

      it 'returns true' do
        expect(item).to be_private
      end
    end

    context 'when item is public' do
      let(:is_public) { true }

      it 'returns false' do
        expect(item).not_to be_private
      end
    end
  end

  describe '#soft_delete' do
    it 'updates deleted_at attribute' do
      item = create(:ai_catalog_item)

      expect { item.soft_delete }.to change { item.deleted_at }.from(nil)
    end
  end

  describe '#definition' do
    let(:version) { item.latest_version }

    context 'when item_type is agent' do
      let(:item) { create(:ai_catalog_agent) }

      it 'returns an AgentDefinition instance' do
        result = item.definition(version.version)

        expect(result).to be_an_instance_of(Ai::Catalog::AgentDefinition)
      end

      it 'passes the item and version to AgentDefinition' do
        expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, version)

        item.definition(version.version)
      end
    end

    context 'when item_type is flow' do
      let(:item) { create(:ai_catalog_flow) }

      it 'returns a FlowDefinition instance' do
        result = item.definition(version.version)

        expect(result).to be_an_instance_of(Ai::Catalog::FlowDefinition)
      end

      it 'passes the item and version to FlowDefinition' do
        expect(Ai::Catalog::FlowDefinition).to receive(:new).with(item, version)

        item.definition(version.version)
      end

      context 'when pinned_version_id is provided' do
        it 'raises an ArgumentError' do
          expect { item.definition(nil, item.versions.first.id) }.to raise_error(
            ArgumentError, 'pinned_version_id is not supported for flows'
          )
        end
      end
    end

    context 'when item_type is third party flow' do
      let(:item) { create(:ai_catalog_third_party_flow) }

      it 'returns the version definition' do
        expect(item.definition).to eq(version.definition)
      end
    end

    describe 'version resolution' do
      let_it_be(:item) { create(:ai_catalog_agent) }
      let_it_be(:v1_1) { create(:ai_catalog_agent_version, item: item, version: '1.1.0') }
      let_it_be(:v2) { create(:ai_catalog_agent_version, item: item, version: '2.0.0') }

      context 'when no version_prefix is pinned' do
        it 'resolves to the latest version' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v2).once

          item.definition
        end
      end

      context 'when a version_prefix is pinned' do
        it 'resolves the correct version' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v1_1).once

          item.definition('1.1.0')
        end
      end

      context 'when a version_id is pinned' do
        it 'returns the version by its id' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v1_1).once

          item.definition(nil, v1_1.id)
        end
      end
    end
  end

  describe '#latest_released_version_with_fallback' do
    let(:item) { build(:ai_catalog_item) }
    let(:latest_released_version) { build(:ai_catalog_item_version, :released) }
    let(:latest_version) { build(:ai_catalog_item_version, :released) }
    let(:draft_version) { build(:ai_catalog_item_version, :draft) }

    subject(:latest_released_version_with_fallback) { item.latest_released_version_with_fallback }

    before do
      allow(item).to receive_messages(latest_released_version: latest_released_version, latest_version: latest_version)
    end

    it { is_expected.to eq(latest_released_version) }

    context 'when latest_released_version is nil' do
      let(:latest_released_version) { nil }

      it { is_expected.to eq(latest_version) }

      context 'when latest_version is a draft' do
        let(:latest_version) { draft_version }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#resolve_version' do
    let_it_be(:item) { create(:ai_catalog_agent) }
    let_it_be(:v1) { create(:ai_catalog_agent_version, item: item, version: '1.0.0') }
    let_it_be(:v1_1) { create(:ai_catalog_agent_version, item: item, version: '1.1.0') }
    let_it_be(:v1_1_1) { create(:ai_catalog_agent_version, item: item, version: '1.1.1') }
    let_it_be(:v1_10) { create(:ai_catalog_agent_version, item: item, version: '1.10.0') }
    let_it_be(:v1_2) { create(:ai_catalog_agent_version, item: item, version: '1.2.0') }
    let_it_be(:v2) { create(:ai_catalog_agent_version, item: item, version: '2.0.0') }

    context 'when no version_prefix is pinned' do
      it 'resolves to the latest version' do
        expect(item.resolve_version).to eq(v2)
      end
    end

    context 'when a major version_prefix is pinned' do
      it 'resolves the correct version' do
        expect(item.resolve_version('1')).to eq(v1_2)
      end
    end

    context 'when a minor version_prefix is pinned' do
      it 'resolves the correct version' do
        expect(item.resolve_version('1.1')).to eq(v1_1_1)
      end
    end

    context 'when a specific version_prefix (patch) is pinned' do
      it 'resolves the correct version' do
        expect(item.resolve_version('1.1.0')).to eq(v1_1)
      end
    end
  end

  describe '#build_new_version' do
    let(:item) { described_class.new }

    it 'builds new version, and sets #latest_version' do
      item.build_new_version({ id: 1 })
      item.build_new_version({ id: 2 })

      expect(item.versions.size).to eq(2)
      expect(item.latest_version).to be_present
      expect(item.latest_version).to eq(item.versions.last)
    end
  end

  describe '#foundational?' do
    subject(:foundational) { item.foundational? }

    let(:is_saas) { false }
    let(:item_id) { 100 }
    let(:item) { build(:ai_catalog_item, :agent, id: item_id) }

    before do
      stub_saas_features(gitlab_duo_saas_only: is_saas)
    end

    context 'when item is agent' do
      context 'when not on GitLab SaaS' do
        let(:is_saas) { false }

        it { is_expected.to be(false) }
      end

      context 'when on GitLab SaaS' do
        let(:is_saas) { true }

        context 'when item is a foundational agent' do
          let(:item_id) { 348 }

          it { is_expected.to be(true) }
        end

        context 'when item is not a foundational agent' do
          it { is_expected.to be(false) }
        end
      end
    end

    context 'when item is flow' do
      let(:item) { create(:ai_catalog_item, :flow, foundational_flow_reference: foundational_flow_reference) }
      let(:foundational_flow_reference) { nil }

      context 'when item has foundational flow reference' do
        let(:foundational_flow_reference) { 'code_review/v1' }

        it { is_expected.to be(true) }
      end

      context 'when item is not a foundational flow' do
        it { is_expected.to be(false) }
      end
    end

    context 'when item is third-party flow' do
      let(:item) { build(:ai_catalog_third_party_flow) }

      it { is_expected.to be(false) }
    end
  end

  describe '#foundational_chat_agent?' do
    subject(:foundational_chat_agent) { item.foundational_chat_agent? }

    let(:is_saas) { false }
    let(:item_id) { 42 }
    let(:item) { build(:ai_catalog_item, :agent, id: item_id) }

    before do
      stub_saas_features(gitlab_duo_saas_only: is_saas)
    end

    context 'when not on GitLab SaaS' do
      it { is_expected.to be(false) }
    end

    context 'when on GitLab SaaS' do
      let(:is_saas) { true }

      context 'when item is a foundational agent' do
        # 348 is the global_catalog_id for the duo_planner foundational agent
        # https://gitlab.com/gitlab-org/gitlab/-/blob/745f1ec2c6622fdfb14f17f8bc932ede44413adb/ee/lib/ai/foundational_chat_agents_definitions.rb#L23
        let(:item_id) { 348 }

        it { is_expected.to be(true) }
      end

      context 'when item is not a foundational agent' do
        it { is_expected.to be(false) }
      end
    end
  end

  describe '#foundational_flow?' do
    subject(:foundational_flow) { item.foundational_flow? }

    context 'when item is not a flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :agent) }

      it { is_expected.to be(false) }
    end

    context 'when item is a non-foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, foundational_flow_reference: nil) }

      it { is_expected.to be(false) }
    end

    context 'when item is a foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, foundational_flow_reference: 'code_review/v1') }

      it { is_expected.to be(true) }
    end
  end

  describe '#foundational_flow' do
    subject(:foundational_flow) { item.foundational_flow }

    let(:item) { build_stubbed(:ai_catalog_item, foundational_flow_reference: foundational_flow_reference) }

    context 'when item does not have a foundational flow reference' do
      let(:foundational_flow_reference) { nil }

      it 'returns nil' do
        expect(foundational_flow).to be_nil
      end
    end

    context 'when item has an invalid foundational flow reference' do
      let(:foundational_flow_reference) { 'foo' }

      it 'returns nil' do
        expect(foundational_flow).to be_nil
      end
    end

    context 'when item has a valid foundational flow reference' do
      let(:foundational_flow_reference) { 'code_review/v1' }

      it 'returns the foundational flow associated with that reference' do
        expect(foundational_flow).to eq(::Ai::Catalog::FoundationalFlow[foundational_flow_reference])
      end
    end
  end
end
