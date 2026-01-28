# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MilestoneQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      search_level: 'global',
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    set_elasticsearch_migration_to(:backfill_traversal_ids_for_milestones, including: true)

    assert_names_in_query(build, with: %w[
      milestone:multi_match:and:search_terms
      milestone:multi_match_phrase:search_terms
      filters:doc:is_a:milestone
      filters:permissions:global:visibility_level:public_and_internal
      filters:non_archived
    ])
  end

  context 'when advanced query syntax is used' do
    let(:query) { 'foo -default' }

    it 'uses simple_query_string in query' do
      assert_names_in_query(build, with: %w[milestone:match:search_terms],
        without: %w[milestone:multi_match:and:search_terms milestone:multi_match_phrase:search_terms])
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'

    describe 'authorization' do
      it 'uses the new authorization filter' do
        set_elasticsearch_migration_to(:backfill_traversal_ids_for_milestones, including: true)

        assert_names_in_query(build,
          with: %w[filters:permissions:global:visibility_level:public_and_internal],
          without: %w[filters:project])
      end

      context 'when backfill_traversal_ids_for_milestones migration has not finished' do
        before do
          set_elasticsearch_migration_to(:backfill_traversal_ids_for_milestones, including: false)
        end

        it 'uses the old authorization filter' do
          assert_names_in_query(build,
            with: %w[filters:project],
            without: %w[filters:permissions:global:visibility_level:public_and_internal])
        end
      end
    end
  end

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
