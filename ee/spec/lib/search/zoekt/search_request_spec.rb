# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SearchRequest, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }
  let_it_be(:user) { create(:user) }
  let(:options) do
    {
      num_context_lines: 20,
      max_file_match_window: 1000,
      max_file_match_results: 5,
      max_line_match_window: 500,
      max_line_match_results: 10,
      max_line_match_results_per_file: Search::Zoekt::MultiMatch::DEFAULT_REQUESTED_CHUNK_SIZE
    }
  end

  describe '#as_json' do
    before do
      allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.id_in([node1.id, node2.id]))
      stub_zoekt_features(traversal_id_search: true)
    end

    subject(:json_representation) do
      described_class.new(current_user: user, query: 'test', **options).as_json
    end

    it 'returns a valid JSON representation of the search request' do
      expect(json_representation).to include({
        version: 2,
        timeout: '120s',
        num_context_lines: 20,
        max_file_match_window: 1000,
        max_file_match_results: 5,
        max_line_match_window: 500,
        max_line_match_results: 10,
        max_line_match_results_per_file: Search::Zoekt::MultiMatch::DEFAULT_REQUESTED_CHUNK_SIZE
      })

      expect(json_representation[:forward_to][0][:endpoint]).to eq(node1.search_base_url)
      expect(json_representation[:forward_to][1][:endpoint]).to eq(node2.search_base_url)

      # Verify the query structure contains our search term
      json_representation[:forward_to].each do |forward|
        expect(forward[:query][:and][:children]).to include({ query_string: { query: 'case:no test' } })
        # Note: more testing is done in code query builder specs
      end
    end

    context 'for project search' do
      let_it_be(:project) { create(:project) }
      let_it_be(:en) { create(:zoekt_enabled_namespace, namespace: project.root_ancestor) }
      let_it_be(:replica) { create(:zoekt_replica, zoekt_enabled_namespace: en, state: :ready) }
      let_it_be(:index) { create(:zoekt_index, zoekt_enabled_namespace: en, replica: replica, node: node2) }

      subject(:json_representation) do
        described_class.new(current_user: user, project_id: project.id, query: 'test', **options).as_json
      end

      it 'returns only node endpoints from the selected replica in forward_to' do
        expect(json_representation[:forward_to].size).to eq(1)
        endpoint = json_representation[:forward_to].first[:endpoint]
        expect(endpoint).to eq(node2.search_base_url)
      end

      context 'with multiple replicas' do
        let_it_be(:replica2) { create(:zoekt_replica, zoekt_enabled_namespace: en, state: :ready) }
        let_it_be(:index2) { create(:zoekt_index, zoekt_enabled_namespace: en, replica: replica2, node: node1) }

        before do
          # Mock ReplicaSelector to return the first replica with its nodes
          selector_result = Search::Zoekt::ReplicaSelector::Result.new(
            replica: replica,
            nodes: [node2]
          )
          allow_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
            allow(instance).to receive(:select).and_return(selector_result)
          end
        end

        it 'returns only nodes from the selected replica' do
          expect(json_representation[:forward_to].size).to eq(1)
          endpoint = json_representation[:forward_to].first[:endpoint]
          expect(endpoint).to eq(node2.search_base_url)
        end
      end
    end

    context 'for group search' do
      let_it_be(:group) { create(:group) }
      let_it_be(:en) { create(:zoekt_enabled_namespace, namespace: group.root_ancestor) }
      let_it_be(:replica) { create(:zoekt_replica, zoekt_enabled_namespace: en, state: :ready) }
      let_it_be(:index1) { create(:zoekt_index, zoekt_enabled_namespace: en, replica: replica, node: node1) }
      let_it_be(:index2) { create(:zoekt_index, zoekt_enabled_namespace: en, replica: replica, node: node2) }

      subject(:json_representation) do
        described_class.new(current_user: user, group_id: group.id, query: 'test', **options).as_json
      end

      it 'returns node endpoints from the selected replica in forward_to' do
        endpoints = json_representation[:forward_to].pluck(:endpoint)
        expect(endpoints).to match_array([node1.search_base_url, node2.search_base_url])
      end
    end

    context 'when zoekt traversal id feature is unavailable' do
      before do
        stub_zoekt_features(traversal_id_search: false)
      end

      subject(:json_representation) do
        described_class.new(current_user: user, query: 'test',
          targets: { node1.id => [1, 2, 3], node2.id => [4, 5, 6] }, **options).as_json
      end

      it 'returns a valid JSON representation of the search request' do
        expect(json_representation).to eq({
          version: 2,
          timeout: '120s',
          num_context_lines: 20,
          max_file_match_window: 1000,
          max_file_match_results: 5,
          max_line_match_window: 500,
          max_line_match_results: 10,
          max_line_match_results_per_file: Search::Zoekt::MultiMatch::DEFAULT_REQUESTED_CHUNK_SIZE,
          forward_to: [
            {
              query: {
                and: { children: [{ query_string: { query: 'case:no test' } },
                  { repo_ids: [1, 2, 3] }] }
              },
              endpoint: node1.search_base_url
            },
            {
              query: {
                and: { children: [{ query_string: { query: 'case:no test' } },
                  { repo_ids: [4, 5, 6] }] }
              },
              endpoint: node2.search_base_url
            }
          ]
        })
      end
    end

    context 'when there is no enabled_namespace' do
      let_it_be(:group) { create(:group) }

      it 'raises an ArgumentError' do
        expect do
          described_class.new(current_user: user, group_id: group.id, query: 'test', **options).as_json
        end.to raise_error(ArgumentError, %r{No enabled namespace found})
      end
    end

    context 'when there are no ready replicas' do
      let_it_be(:group) { create(:group) }
      let_it_be(:_) { create(:zoekt_enabled_namespace, namespace: group) }

      it 'raises an ArgumentError' do
        expect do
          described_class.new(current_user: user, group_id: group.id, query: 'test', **options).as_json
        end.to raise_error(ArgumentError, %r{No ready replica found})
      end
    end

    context 'when there is no online nodes' do
      let_it_be(:group) { create(:group) }
      let_it_be(:en) { create(:zoekt_enabled_namespace, namespace: group) }
      let_it_be(:replica) { create(:zoekt_replica, zoekt_enabled_namespace: en, state: :ready) }

      before do
        selector_result = Search::Zoekt::ReplicaSelector::Result.new(replica: replica, nodes: [])
        allow_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
          allow(instance).to receive(:select).and_return(selector_result)
        end
      end

      it 'raises an ArgumentError' do
        expect do
          described_class.new(current_user: user, group_id: group.id, query: 'test', **options).as_json
        end.to raise_error(ArgumentError, %r{No online nodes found for replica})
      end
    end
  end

  describe '#project_level?' do
    subject(:project_level) { described_class.new(current_user: user, query: 'test', **options).project_level? }

    context 'when project_id is provided' do
      let(:options) { { project_id: 99 } }

      it { is_expected.to be true }
    end

    context 'when group_id is provided' do
      let(:options) { { group_id: 42 } }

      it { is_expected.to be false }
    end

    context 'when neither group_id nor project_id is provided' do
      let(:options) { {} }

      it { is_expected.to be false }
    end
  end

  describe '#group_level?' do
    subject(:group_level) { described_class.new(current_user: user, query: 'test', **options).group_level? }

    context 'when group_id is provided' do
      let(:options) { { group_id: 42 } }

      it { is_expected.to be true }
    end

    context 'when project_id is provided' do
      let(:options) { { project_id: 99 } }

      it { is_expected.to be false }
    end

    context 'when neither group_id nor project_id is provided' do
      let(:options) { {} }

      it { is_expected.to be false }
    end
  end

  describe '#global_level?' do
    subject(:global_level) { described_class.new(current_user: user, query: 'test', **options).global_level? }

    context 'when neither group_id nor project_id is provided' do
      let(:options) { {} }

      it { is_expected.to be true }
    end

    context 'when group_id is provided' do
      let(:options) { { group_id: 42 } }

      it { is_expected.to be false }
    end

    context 'when project_id is provided' do
      let(:options) { { project_id: 99 } }

      it { is_expected.to be false }
    end
  end
end
