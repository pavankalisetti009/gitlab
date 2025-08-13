# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SearchRequest, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }
  let_it_be(:user) { create(:user) }

  describe '#as_json' do
    before do
      allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.id_in([node1.id, node2.id]))
    end

    subject(:json_representation) do
      described_class.new(current_user: user, search_level: :global, query: 'test').as_json
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
        max_line_match_results_per_file: 3
      })

      expect(json_representation[:forward_to][0][:endpoint]).to eq(node1.search_base_url)
      expect(json_representation[:forward_to][1][:endpoint]).to eq(node2.search_base_url)

      # Verify the query structure contains our search term
      json_representation[:forward_to].each do |forward|
        expect(forward[:query][:and][:children]).to include({ query_string: { query: 'test' } })
        # Note: more testing is done in code query builder specs
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
          max_line_match_results_per_file: 3,
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
            max_line_match_results_per_file: 3,
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
end
