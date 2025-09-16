# frozen_string_literal: true

RSpec.shared_examples_for 'Ai::Catalog::Concerns::FlowVersion' do
  let_it_be(:agent1) { create(:ai_catalog_item, :agent) }
  let_it_be(:agent2) { create(:ai_catalog_item, :agent) }
  let_it_be(:agent3) { create(:ai_catalog_item, :agent) }

  describe 'validations' do
    it 'does not allow a released version without steps' do
      version = build(
        :ai_catalog_item_version,
        :released,
        :for_flow,
        'definition' => { 'steps' => [], 'triggers' => [] }
      )

      expect(version).not_to be_valid
      expect(version.errors[:definition]).to include(s_('AICatalog|must have at least one node'))
    end

    it 'allow a released version with steps' do
      version = build(:ai_catalog_item_version, :released, :for_flow)

      expect(version).to be_valid
    end

    it 'allows an unreleased version to have no steps' do
      version = build(
        :ai_catalog_item_version,
        :for_flow,
        'definition' => { 'steps' => [], 'triggers' => [] }
      )

      expect(version).to be_valid
    end

    it 'allows a released agent version to not have steps' do
      version = build(:ai_catalog_agent_version, :for_agent, :released)

      expect(version).to be_valid
    end
  end

  describe '#delete_no_longer_used_dependencies' do
    let_it_be(:flow_version) do
      create(
        :ai_catalog_item_version,
        :for_flow,
        'definition' => {
          'steps' => [
            { 'agent_id' => agent1.id, 'current_version_id' => 1, 'pinned_version_prefix' => nil },
            { 'agent_id' => agent2.id, 'current_version_id' => 1, 'pinned_version_prefix' => nil }
          ],
          'triggers' => []
        }
      )
    end

    let_it_be(:dependency_for_agent_1) do
      create(
        :ai_catalog_item_version_dependency, ai_catalog_item_version: flow_version, dependency_id: agent1.id
      )
    end

    let_it_be(:dependency_for_agent_2) do
      create(
        :ai_catalog_item_version_dependency, ai_catalog_item_version: flow_version, dependency_id: agent2.id
      )
    end

    let_it_be(:dependency_for_agent_3) do
      create(
        :ai_catalog_item_version_dependency, ai_catalog_item_version: flow_version, dependency_id: agent3.id
      )
    end

    subject(:delete_no_longer_used_dependencies) { flow_version.delete_no_longer_used_dependencies }

    it 'updates the dependencies' do
      delete_no_longer_used_dependencies

      expect(flow_version.reload.dependencies.pluck(:dependency_id)).to contain_exactly(agent1.id, agent2.id)
    end

    it 'does not delete the old dependencies that exist in the new version' do
      dependency_to_keep = flow_version.dependencies.find_by(dependency_id: agent1.id)

      delete_no_longer_used_dependencies

      expect(flow_version.dependencies.find_by_id(dependency_to_keep)).not_to be_nil
    end

    context 'when there are other item versions with dependencies' do
      let_it_be(:other_flow_version_dependency) { create(:ai_catalog_item_version_dependency) }

      it 'does not affect dependencies from other records' do
        expect { delete_no_longer_used_dependencies }
          .not_to change { Ai::Catalog::ItemVersionDependency.find(other_flow_version_dependency.id) }
      end
    end
  end

  describe '#dependency_ids' do
    let(:flow_version) do
      build(
        :ai_catalog_item_version,
        :for_flow,
        'definition' => {
          'steps' => [
            { 'agent_id' => agent1.id, 'current_version_id' => 1, 'pinned_version_prefix' => nil },
            { 'agent_id' => agent2.id, 'current_version_id' => 1, 'pinned_version_prefix' => nil },
            { 'agent_id' => agent1.id, 'current_version_id' => 1, 'pinned_version_prefix' => nil }
          ],
          'triggers' => []
        }
      )
    end

    it 'returns the unique agent_ids from the steps' do
      expect(flow_version.dependency_ids).to contain_exactly(agent1.id, agent2.id)
    end
  end
end
