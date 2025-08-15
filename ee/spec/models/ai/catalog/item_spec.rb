# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Item, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:project).optional }

    it { is_expected.to have_many(:versions) }
    it { is_expected.to have_many(:consumers) }

    it { is_expected.to have_one(:latest_version) }

    describe '#latest_version' do
      it 'returns the latest version' do
        item = create(:ai_catalog_item, :with_version)
        latest_version = create(:ai_catalog_item_version, item: item, version: '1.0.1')

        expect(item.latest_version).to eq(latest_version)
      end
    end
  end

  describe 'validations' do
    it { expect(build(:ai_catalog_item)).to be_valid }

    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_length_of(:name).is_at_most(255) }
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
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:item_type).with_values(agent: 1, flow: 2) }
  end

  describe 'scopes' do
    describe '.for_organization' do
      let_it_be(:item_1) { create(:ai_catalog_item, organization: create(:organization)) }
      let_it_be(:item_2) { create(:ai_catalog_item, organization: create(:organization)) }

      it 'returns items for the specified organization' do
        expect(described_class.for_organization(item_1.organization)).to contain_exactly(item_1)
      end
    end

    describe '.not_deleted' do
      let_it_be(:items) { create_list(:ai_catalog_item, 2) }
      let_it_be(:deleted_items) { create_list(:ai_catalog_item, 2, deleted_at: 1.day.ago) }

      it 'returns not deleted items' do
        expect(described_class.not_deleted).to match_array(items)
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

  describe '#soft_delete' do
    it 'updates deleted_at attribute' do
      item = create(:ai_catalog_item)

      expect { item.soft_delete }.to change { item.deleted_at }.from(nil)
    end
  end

  describe '#definition' do
    let(:version) { item.latest_version }

    context 'when item_type is agent' do
      let(:item) { create(:ai_catalog_agent, :with_version) }

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
      let(:item) { create(:ai_catalog_flow, :with_version) }

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
end
