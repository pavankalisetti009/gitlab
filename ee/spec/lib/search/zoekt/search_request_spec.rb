# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SearchRequest, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }
  let_it_be(:user) { create(:user) }
  let(:options) { {} }

  describe '#as_json' do
    before do
      allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.id_in([node1.id, node2.id]))
    end

    subject(:json_representation) do
      described_class.new(current_user: user, search_level: :global, query: 'test', **options).as_json
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
        expect(forward[:query][:and][:children]).to include({ query_string: { query: 'test' } })
        # Note: more testing is done in code query builder specs
      end
    end

    context 'when max_line_match_results_per_file is set' do
      let(:options) { { max_line_match_results_per_file: 123 } }

      it 'returns the specified max_line_match_results_per_file' do
        expect(json_representation[:max_line_match_results_per_file]).to eq(123)
      end
    end

    context 'when zoekt traversal id feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_traversal_id_queries: false)
      end

      subject(:json_representation) do
        described_class.new(current_user: user, query: 'test',
          targets: { node1.id => [1, 2, 3], node2.id => [4, 5, 6] }).as_json
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
                and: { children: [{ query_string: { query: 'test' } }, { or: { children: [
                  { meta: { key: 'project_id', value: '^1$' } },
                  { meta: { key: 'project_id', value: '^2$' } },
                  { meta: { key: 'project_id', value: '^3$' } }
                ] } }] }
              },
              endpoint: node1.search_base_url
            },
            {
              query: {
                and: { children: [{ query_string: { query: 'test' } }, { or: { children: [

                  { meta: { key: 'project_id', value: '^4$' } },
                  { meta: { key: 'project_id', value: '^5$' } },
                  { meta: { key: 'project_id', value: '^6$' } }
                ] } }] }
              },
              endpoint: node2.search_base_url
            }
          ]
        })
      end

      context 'and zoekt_search_meta_project_ids feature flag is disabled' do
        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)
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
                  and: { children: [{ query_string: { query: 'test' } }, { repo_ids: [1, 2, 3] }] }
                },
                endpoint: node1.search_base_url
              },
              {
                query: {
                  and: { children: [{ query_string: { query: 'test' } }, { repo_ids: [4, 5, 6] }] }
                },
                endpoint: node2.search_base_url
              }
            ]
          })
        end
      end
    end

    context 'when there is no enabled_namespace' do
      let_it_be(:group) { create(:group) }

      it 'raises an ArgumentError' do
        expect do
          described_class.new(current_user: user, group_id: group.id, query: 'test').as_json
        end.to raise_error(ArgumentError, %r{No enabled namespace found for root ancestor})
      end
    end

    context 'when there is no online nodes' do
      let_it_be(:group) { create(:group) }
      let_it_be(:en) { create(:zoekt_enabled_namespace, namespace: group) }

      before do
        allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.none)
      end

      it 'raises an ArgumentError' do
        expect do
          described_class.new(current_user: user, group_id: group.id, query: 'test').as_json
        end.to raise_error(ArgumentError, %r{No online nodes found for namespace})
      end
    end
  end

  describe '#search_level' do
    subject(:search_level) do
      described_class.new(current_user: user, query: 'test', **options).search_level
    end

    context 'when group_id is provided' do
      let(:options) { { group_id: 42 } }

      it { is_expected.to eq(:group) }
    end

    context 'when project_id is provided' do
      let(:options) { { project_id: 99 } }

      it { is_expected.to eq(:project) }

      context 'and group_id is also provided' do
        let(:options) { { group_id: 42, project_id: 99 } }

        it { is_expected.to eq(:project) }
      end
    end

    context 'when neither group_id nor project_id is provided' do
      it { is_expected.to eq(:global) }
    end
  end
end
