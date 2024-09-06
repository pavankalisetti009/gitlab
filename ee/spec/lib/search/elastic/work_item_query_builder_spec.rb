# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::WorkItemQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      klass: Issue, # For rendering the UI
      index_name: ::Search::Elastic::References::WorkItem.index,
      not_work_item_type_ids: [::WorkItems::Type.find_by_name(::WorkItems::Type::TYPE_NAMES[:epic]).id],
      public_and_internal_projects: false,
      search_level: 'global'
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      work_item:multi_match:or:search_terms
      work_item:multi_match:and:search_terms
      work_item:multi_match_phrase:search_terms
      filters:not_hidden
      filters:not_work_item_type_ids
      filters:non_archived
      filters:non_confidential
      filters:confidential
      filters:confidential:as_author
      filters:confidential:as_assignee
      filters:confidential:project:membership:id
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[work_item:related:iid doc:is_a:work_item])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:or:search_terms
            work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:or:search_terms
              work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end

      context 'when search_uses_match_queries is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:or:search_terms
              work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'
    it_behaves_like 'a query filtered by confidentiality'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
      end
    end

    describe 'labels' do
      let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }

      it 'does not include labels filter by default' do
        assert_names_in_query(build, without: %w[filters:label_ids])
      end

      context 'when labels option is provided' do
        let(:options) { base_options.merge(labels: [label.id]) }

        it 'applies label filters' do
          assert_names_in_query(build, with: %w[filters:label_ids])
        end
      end

      context 'when label_name option is provided' do
        let(:options) { base_options.merge(label_name: [label.name]) }

        it 'applies label filters' do
          assert_names_in_query(build, with: %w[filters:label_ids])
        end
      end

      context 'when both labels and label_name options are provided' do
        let(:options) { base_options.merge(labels: [label.id], label_name: [label.name]) }

        it 'applies label filters' do
          assert_names_in_query(build, with: %w[filters:label_ids])
        end
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
    it_behaves_like 'a query that is paginated'
  end
end
