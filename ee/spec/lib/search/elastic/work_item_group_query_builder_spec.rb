# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::WorkItemGroupQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:work_item_type) { FactoryBot.build(:work_item_system_defined_type, :epic) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: [],
      group_ids: [],
      klass: WorkItem,
      index_name: ::Search::Elastic::References::WorkItem.index,
      work_item_type_ids: [work_item_type.id],
      public_and_internal_projects: false,
      search_level: 'global'
    }
  end

  let(:query) { 'foo' }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      work_item:multi_match:and:search_terms
      work_item:multi_match_phrase:search_terms
      filters:permissions:global
      filters:permissions:global:namespace_visibility_level:public_and_internal
      filters:not_hidden
      filters:work_item_type_ids
      filters:non_archived
      filters:confidentiality:groups:non_confidential
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
      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:private_group) { create(:group, :private) }
    let_it_be(:private_project) { create(:project, :private, namespace: private_group) }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'

    context 'with labels' do
      let_it_be(:authorized_group) { create(:group, :private, developers: user) }
      let_it_be(:authorized_project) { create(:project, :private, group: authorized_group) }
      let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }

      it_behaves_like 'a query filtered by labels'
    end

    describe 'confidentiality' do
      context 'when user has role set in min_access_level_non_confidential option' do
        context 'in group' do
          it 'applies non-confidential filters and confidential for assignees and authors' do
            private_group.add_guest(user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:confidential:as_author])
          end
        end

        context 'in project' do
          it 'applies non-confidential and confidential for assignees and authors' do
            private_project.add_guest(user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:confidential:as_author])
          end
        end
      end

      context 'when user has role set in min_access_level_confidential option' do
        context 'in group' do
          it 'applies the expected membership filters' do
            private_group.add_planner(user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:private:ancestry_filter:descendants],
              without: %w[filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
                filters:confidentiality:groups:public_and_internal:confidential:as_author])
          end
        end

        context 'in project' do
          it 'applies the expected membership filters' do
            private_project.add_planner(user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:private:ancestry_filter:descendants],
              without: %w[filters:confidentiality:groups:public_and_internal:confidential:as_author
                filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants])
          end
        end
      end

      context 'when user does not have role' do
        it 'only applies the non-confidential filters' do
          assert_names_in_query(build,
            with: %w[filters:confidentiality:groups:non_confidential
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:confidential:as_assignee],
            without: %w[filters:confidentiality:groups:private:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:confidential:as_author])
        end
      end

      context 'when there is no user' do
        let(:user) { nil }

        it 'only applies the non-confidential filter' do
          assert_names_in_query(build,
            with: %w[filters:confidentiality:groups:non_confidential],
            without: %w[filters:confidentiality:groups:confidential:as_author
              filters:confidentiality:groups:confidential:as_assignee
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:private:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants])
        end
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it 'applies no confidential filters' do
          assert_names_in_query(build,
            without: %w[filters:confidentiality:groups:non_confidential
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:public_and_internal:confidential:as_author
              filters:confidentiality:groups:public_and_internal:confidential:as_assignee
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
              filters:confidentiality:groups:private:ancestry_filter:descendants])
        end
      end
    end

    describe 'authorization' do
      let_it_be(:authorized_group) { create(:group, :private, developers: user) }

      context 'for global search' do
        let(:options) do
          base_options.merge(search_level: :global, group_ids: [])
        end

        it 'applies authorization filters' do
          assert_names_in_query(build, with: %w[filters:permissions:global
            filters:permissions:global:namespace_visibility_level:public_and_internal])
        end

        context 'when user can read all resources' do
          before do
            allow(user).to receive(:can_read_all_resources?).and_return(true)
          end

          it 'bypasses authorization filters' do
            assert_names_in_query(build, without: %w[filters:permissions:global
              filters:permissions:global:namespace_visibility_level:public_and_internal])
          end
        end
      end

      context 'for group search' do
        let(:options) do
          base_options.merge(search_level: :group, group_ids: [authorized_group.id])
        end

        it 'applies authorization filters' do
          assert_names_in_query(build, with: %w[filters:level:group
            filters:permissions:group:namespace_visibility_level:public_and_internal
            filters:permissions:group:namespace_visibility_level:private])
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
