# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::WorkItemQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      klass: Issue, # For rendering the UI
      index_name: ::Search::Elastic::References::WorkItem.index,
      not_work_item_type_ids: [::WorkItems::Type.find_by_name(::WorkItems::Type::TYPE_NAMES[:epic]).id],
      public_and_internal_projects: false,
      search_level: :global,
      related_ids: [1]
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [project.id] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  context 'when search_project_confidentiality_use_traversal_ids is false' do
    before do
      stub_feature_flags(search_project_confidentiality_use_traversal_ids: false)
    end

    it 'contains all expected filters' do
      assert_names_in_query(build, with: %w[
        work_item:multi_match:and:search_terms
        work_item:multi_match_phrase:search_terms
        filters:permissions:global:project_visibility_level:public_and_internal
        filters:not_hidden
        filters:not_work_item_type_ids
        filters:non_archived
        filters:confidentiality:projects:non_confidential
        filters:confidentiality:projects:confidential
        filters:confidentiality:projects:confidential:as_author
        filters:confidentiality:projects:confidential:as_assignee
        filters:confidentiality:projects:confidential:project:membership:id
      ])
    end
  end

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      work_item:multi_match:and:search_terms
      work_item:multi_match_phrase:search_terms
      filters:permissions:global:project_visibility_level:public_and_internal
      filters:not_hidden
      filters:not_work_item_type_ids
      filters:non_archived
      filters:confidentiality:projects:non_confidential
      filters:confidentiality:projects:confidential
      filters:confidentiality:projects:confidential:as_author
      filters:confidentiality:projects:confidential:as_assignee
      filters:confidentiality:projects:private:project:member
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:related:iid doc:is_a:work_item],
          without: %w[work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms work_item:related:ids])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:and:search_terms work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
      end

      describe 'related id query' do
        context 'for global search' do
          context 'when search_work_item_queries_notes is false' do
            before do
              stub_feature_flags(search_work_item_queries_notes: false)
            end

            it 'does not contain work_item:related:ids in query' do
              assert_names_in_query(build, without: %w[work_item:related:ids])
            end
          end

          context 'when search_work_item_queries_notes is true' do
            context 'when on saas', :saas do
              it 'does not contain work_item:related:ids in query' do
                assert_names_in_query(build, without: %w[work_item:related:ids])
              end
            end

            context 'when not on saas' do
              it 'contains work_item:related:ids in query' do
                assert_names_in_query(build, with: %w[work_item:related:ids])
              end
            end
          end
        end

        context 'for group search' do
          let(:options) { base_options.merge(search_level: :group, group_ids: [1], project_ids: [1]) }

          it 'contains work_item:related:ids in query' do
            assert_names_in_query(build, with: %w[work_item:related:ids])
          end
        end

        context 'for project search' do
          let(:options) { base_options.merge(search_level: :project, group_ids: [], project_ids: [1]) }

          it 'contains work_item:related:ids in query' do
            assert_names_in_query(build, with: %w[work_item:related:ids])
          end
        end

        context 'when options[:related_ids] is not sent' do
          let(:options) do
            base_options.tap { |hash| hash.delete(:related_ids) }
          end

          it 'returns the expected query' do
            assert_names_in_query(build,
              with: %w[work_item:multi_match:and:search_terms work_item:multi_match_phrase:search_terms],
              without: %w[work_item:match:search_terms work_item:related:ids])
          end
        end

        context 'when search_work_item_queries_notes flag is false' do
          before do
            stub_feature_flags(search_work_item_queries_notes: false)
          end

          it 'returns the expected query' do
            assert_names_in_query(build,
              with: %w[work_item:multi_match:and:search_terms work_item:multi_match_phrase:search_terms],
              without: %w[work_item:match:search_terms work_item:related:ids])
          end
        end
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

  describe 'hybrid search', :saas do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project) { create(:project) }
    let(:helper) { instance_double(Gitlab::Elastic::Helper) }
    let(:project_ids) { [project.id] }
    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }
    let(:hybrid_similarity) { 0.5 }
    let(:hybrid_boost) { 0.5 }
    let(:query) { 'test with long query' }
    let(:options) do
      base_options.merge(hybrid_similarity: hybrid_similarity, hybrid_boost: hybrid_boost)
    end

    before do
      allow(user).to receive(:any_group_with_ai_available?).and_return(true)
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:vectors_supported?).and_return(true)
      allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(false)
    end

    context 'when we cannot generate embeddings' do
      before do
        allow(embedding_service).to receive(:execute).and_return(nil)
      end

      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    context 'when we have both opensearch and elasticsearch not running' do
      before do
        allow(helper).to receive(:vectors_supported?).with(:elasticsearch).and_return(false)
        allow(helper).to receive(:vectors_supported?).with(:opensearch).and_return(false)
      end

      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    context 'when we have opensearch running' do
      before do
        allow(helper).to receive(:vectors_supported?).with(:elasticsearch).and_return(false)
        allow(helper).to receive(:vectors_supported?).with(:opensearch).and_return(true)
      end

      it 'adds a knn query for opensearch on the embedding_1 field using the text-embedding-005 model' do
        model = 'text-embedding-005'
        expect(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new)
          .with(anything, user: anything, tracking_context: anything, unit_primitive: anything, model: model)
          .and_return(embedding_service)

        query = build
        os_knn_query = {
          knn: {
            embedding_1: {
              k: 25,
              vector: mock_embedding
            }
          }
        }
        expect(query[:query][:bool][:should]).to include(os_knn_query)
      end

      context 'when simple_query_string is used' do
        # advanced search syntax forces use of simple_query_string
        let(:query) { 'test with long query and 1*' }

        it 'applies boost to the query' do
          query_hash = build
          os_knn_query = {
            knn: {
              embedding_1: {
                k: 25,
                vector: mock_embedding
              }
            }
          }
          simple_qs_with_boost = {
            simple_query_string: {
              _name: "work_item:match:search_terms",
              fields: described_class::FIELDS,
              query: query,
              lenient: true,
              default_operator: :and,
              boost: 0.2
            }
          }
          expect(query_hash[:query][:bool][:should]).to include(simple_qs_with_boost, os_knn_query)
        end
      end
    end

    shared_examples 'without hybrid search query' do
      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    it 'adds a knn query with the same filters as the bool filters' do
      query = build

      expect(query).to have_key(:knn)
      expect(query[:knn][:query_vector]).to eq(mock_embedding)
      expect(query[:knn][:similarity]).to eq(hybrid_similarity)
      expect(query[:knn][:boost]).to eq(hybrid_boost)

      expected_filters = %w[
        filters:permissions:global:project_visibility_level:public_and_internal
        filters:confidentiality:projects:non_confidential
        filters:confidentiality:projects:confidential
        filters:confidentiality:projects:confidential:as_author
        filters:confidentiality:projects:confidential:as_assignee
        filters:confidentiality:projects:private:project:member
      ]

      knn_filter = query[:knn][:filter]
      query_without_knn = query.except(:knn)

      assert_names_in_query(knn_filter, with: expected_filters)
      assert_names_in_query(query_without_knn, with: expected_filters)
    end

    context 'when query is short' do
      let(:query) { 'foo' }

      it_behaves_like 'without hybrid search query'
    end

    context 'if project_ids is not specified' do
      let(:project_ids) { [] }

      it_behaves_like 'without hybrid search query'
    end

    context 'if user is not authorized to perform ai actions' do
      before do
        allow(user).to receive(:any_group_with_ai_available?).and_return(false)
      end

      it_behaves_like 'without hybrid search query'
    end

    context 'with embeddings not available' do
      where(:hybrid_work_item_search, :ai_global_switch, :work_item_embedding, :ai_available) do
        false | false | false | false
        true  | false | false | false
        false | true  | false | false
        false | false | true  | false
        false | false | false | true
        false | false | false | false
      end

      with_them do
        before do
          stub_feature_flags(search_work_items_hybrid_search: hybrid_work_item_search)
          stub_feature_flags(ai_global_switch: ai_global_switch)
          stub_feature_flags(elasticsearch_work_item_embedding: work_item_embedding)
          allow(Gitlab::Saas).to receive(:feature_available?).and_return(ai_available)
        end

        it_behaves_like 'without hybrid search query'
      end
    end

    context 'when the query is with fields' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
        assert_fields_in_query(build, with: %w[title])
      end
    end
  end

  describe 'filters' do
    let_it_be(:group) { create(:group) }
    let_it_be(:private_project) { create(:project, :private, group: group) }
    let_it_be(:authorized_project) { create(:project, developers: [user], group: group) }
    let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'

    it_behaves_like 'a query filtered by confidentiality' do
      let(:query_name_project_membership) { 'filters:confidentiality:projects:private:project:member' }
    end

    context 'when search_project_confidentiality_use_traversal_ids is false' do
      before do
        stub_feature_flags(search_project_confidentiality_use_traversal_ids: false)
      end

      it_behaves_like 'a query filtered by confidentiality'
    end

    it_behaves_like 'a query filtered by author'
    it_behaves_like 'a query filtered by labels'
    it_behaves_like 'a query filtered by project authorization'

    context 'with milestones' do
      let_it_be(:milestone) { create(:milestone, project: authorized_project) }

      context 'when backfill_work_item_milestone_data has finished' do
        before do
          set_elasticsearch_migration_to(:backfill_work_item_milestone_data, including: true)
        end

        it 'does not apply milestone filters by default' do
          assert_names_in_query(build,
            without: %w[
              filters:milestone_title
              filters:not_milestone_title
              filters:none_milestones
              filters:any_milestones
            ])
        end

        context 'when milestone_title option is provided' do
          let(:options) { base_options.merge(milestone_title: milestone.title) }

          it 'applies the filter' do
            assert_names_in_query(build, with: %w[filters:milestone_title])
          end
        end

        context 'when not_milestone_title option is provided' do
          let(:options) { base_options.merge(not_milestone_title: milestone.title) }

          it 'applies the filter' do
            assert_names_in_query(build, with: %w[filters:not_milestone_title])
          end
        end

        context 'when none_milestones option is provided' do
          let(:options) { base_options.merge(none_milestones: true) }

          it 'applies the filter' do
            assert_names_in_query(build, with: %w[filters:none_milestones])
          end
        end

        context 'when any_milestones option is provided' do
          let(:options) { base_options.merge(any_milestones: true) }

          it 'applies the filter' do
            assert_names_in_query(build, with: %w[filters:any_milestones])
          end
        end
      end

      context 'when backfill_work_item_milestone_data has not finished' do
        before do
          set_elasticsearch_migration_to(:backfill_work_item_milestone_data, including: false)
        end

        context 'when all milestone options are provided' do
          let(:options) do
            base_options.merge(
              milestone_title: milestone.title,
              not_milestone_title: milestone.title,
              none_milestones: true,
              any_milestones: true
            )
          end

          it 'does not apply any milestone filters' do
            assert_names_in_query(build,
              without: %w[
                filters:milestone_title
                filters:not_milestone_title
                filters:none_milestones
                filters:any_milestones
              ])
          end
        end
      end

      context 'when backfill_milestone_state_work_items_index has finished' do
        before do
          set_elasticsearch_migration_to(:backfill_milestone_state_work_items_index, including: true)
        end

        context 'when milestone_state_filters option is provided' do
          context 'with upcoming filter' do
            let(:options) { base_options.merge(milestone_state_filters: [:upcoming]) }

            it 'applies the milestone upcoming state filter' do
              assert_names_in_query(build, with: %w[filters:milestone_state_upcoming])
            end
          end

          context 'with not_upcoming filter' do
            let(:options) { base_options.merge(milestone_state_filters: [:not_upcoming]) }

            it 'applies the milestone upcoming state filter' do
              assert_names_in_query(build, with: %w[filters:milestone_state_not_upcoming])
            end
          end

          context 'with started filter' do
            let(:options) { base_options.merge(milestone_state_filters: [:started]) }

            it 'applies the milestone upcoming state filter' do
              assert_names_in_query(build, with: %w[filters:milestone_state_started])
            end
          end

          context 'with not_started filter' do
            let(:options) { base_options.merge(milestone_state_filters: [:not_started]) }

            it 'applies the milestone upcoming state filter' do
              assert_names_in_query(build, with: %w[filters:milestone_state_not_started])
            end
          end
        end
      end

      context 'when backfill_milestone_state_work_items_index has not finished' do
        before do
          set_elasticsearch_migration_to(:backfill_milestone_state_work_items_index, including: false)
        end

        context 'when milestone_state_filters options are provided' do
          let(:options) do
            base_options.merge(milestone_state_filters: [:started])
          end

          it 'does not apply milestone state filters' do
            assert_names_in_query(build, without: %w[filters:milestone_state_filters])
          end
        end
      end
    end

    describe 'assignees' do
      let_it_be(:assignee_user) { create(:user) }
      let_it_be(:other_user) { create(:user) }

      it 'does not apply assignee filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:assignee_ids
            filters:not_assignee_ids
            filters:or_assignee_ids
            filters:none_assignees
            filters:any_assignees
          ])
      end

      context 'when assignee_ids option is provided' do
        let(:options) { base_options.merge(assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:assignee_ids])
        end
      end

      context 'when not_assignee_ids option is provided' do
        let(:options) { base_options.merge(not_assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_assignee_ids])
        end
      end

      context 'when or_assignee_ids option is provided' do
        let(:options) { base_options.merge(or_assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:or_assignee_ids])
        end
      end

      context 'when none_assignees option is provided' do
        let(:options) { base_options.merge(none_assignees: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_assignees])
        end
      end

      context 'when any_assignees option is provided' do
        let(:options) { base_options.merge(any_assignees: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_assignees])
        end
      end

      context 'when multiple assignee options are provided' do
        let(:options) do
          base_options.merge(
            assignee_ids: [assignee_user.id],
            not_assignee_ids: [other_user.id],
            or_assignee_ids: [assignee_user.id, other_user.id],
            none_assignees: true,
            any_assignees: true
          )
        end

        it 'applies all provided assignee filters' do
          assert_names_in_query(build, with: %w[
            filters:assignee_ids
            filters:not_assignee_ids
            filters:or_assignee_ids
            filters:none_assignees
            filters:any_assignees
          ])
        end
      end
    end

    describe 'label names' do
      it 'does not apply label filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:label_names
            filters:not_label_names
            filters:or_label_names
            filters:none_label_names
            filters:any_label_names
          ])
      end

      context 'when label_names option is provided' do
        let(:options) { base_options.merge(label_names: ['workflow::*', 'backend']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:label_names])
        end
      end

      context 'when not_label_names option is provided' do
        let(:options) { base_options.merge(not_label_names: ['workflow::in dev', 'group::*']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_label_names])
        end
      end

      context 'when or_label_names option is provided' do
        let(:options) { base_options.merge(or_label_names: ['workflow::*', 'group::knowledge']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:or_label_names])
        end
      end

      context 'when none_label_names option is provided' do
        let(:options) { base_options.merge(none_label_names: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_label_names])
        end
      end

      context 'when any_label_names option is provided' do
        let(:options) { base_options.merge(any_label_names: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_label_names])
        end
      end

      context 'when multiple label options are provided' do
        let(:options) do
          base_options.merge(
            label_names: ['workflow::complete'],
            not_label_names: ['group::*'],
            or_label_names: %w[backend frontend],
            none_label_names: false,
            any_label_names: false
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end

      context 'when mixed ANY with nested filters' do
        let(:options) do
          base_options.merge(
            any_label_names: true,
            not_label_names: ['workflow::in dev'],
            or_label_names: %w[frontend backend]
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:any_label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end

      context 'when mixed NONE with nested filters' do
        let(:options) do
          base_options.merge(
            none_label_names: true,
            not_label_names: ['group::*'],
            or_label_names: %w[frontend backend]
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:none_label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end
    end

    describe 'weight' do
      it 'does not apply weight filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:weight
            filters:not_weight
            filters:none_weight
            filters:any_weight
          ])
      end

      context 'when weight option is provided' do
        let(:options) { base_options.merge(weight: 3) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:weight])
        end
      end

      context 'when not_weight option is provided' do
        let(:options) { base_options.merge(not_weight: 2) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_weight])
        end
      end

      context 'when none_weight option is provided' do
        let(:options) { base_options.merge(none_weight: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_weight])
        end
      end

      context 'when any_weight option is provided' do
        let(:options) { base_options.merge(any_weight: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_weight])
        end
      end
    end

    describe 'health_status' do
      it 'does not apply health_status filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:health_status
            filters:not_health_status
            filters:none_health_status
            filters:any_health_status
          ])
      end

      context 'when health_status option is provided' do
        let(:options) { base_options.merge(health_status: [1]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:health_status])
        end
      end

      context 'when not_health_status option is provided' do
        let(:options) { base_options.merge(not_health_status: [2]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_health_status])
        end
      end

      context 'when none_health_status option is provided' do
        let(:options) { base_options.merge(none_health_status: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_health_status])
        end
      end

      context 'when any_health_status option is provided' do
        let(:options) { base_options.merge(any_health_status: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_health_status])
        end
      end
    end

    describe 'closed_at' do
      it 'does not apply closed_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:closed_after
            filters:closed_before
          ])
      end

      context 'when closed_after option is provided' do
        let(:options) { base_options.merge(closed_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:closed_after])
        end
      end

      context 'when closed_before option is provided' do
        let(:options) { base_options.merge(closed_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:closed_before])
        end
      end

      context 'when both closed_after and closed_before options are provided' do
        let(:options) do
          base_options.merge(closed_after: '2025-01-01T00:00:00Z', closed_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:closed_after filters:closed_before])
        end
      end
    end

    describe 'created_at' do
      it 'does not apply created_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:created_after
            filters:created_before
          ])
      end

      context 'when created_after option is provided' do
        let(:options) { base_options.merge(created_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:created_after])
        end
      end

      context 'when created_before option is provided' do
        let(:options) { base_options.merge(created_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:created_before])
        end
      end

      context 'when both created_after and created_before options are provided' do
        let(:options) do
          base_options.merge(created_after: '2025-01-01T00:00:00Z', created_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:created_after filters:created_before])
        end
      end
    end

    describe 'updated_at' do
      it 'does not apply updated_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:updated_after
            filters:updated_before
          ])
      end

      context 'when updated_after option is provided' do
        let(:options) { base_options.merge(updated_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:updated_after])
        end
      end

      context 'when updated_before option is provided' do
        let(:options) { base_options.merge(updated_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:updated_before])
        end
      end

      context 'when both updated_after and updated_before options are provided' do
        let(:options) do
          base_options.merge(updated_after: '2025-01-01T00:00:00Z', updated_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:updated_after filters:updated_before])
        end
      end
    end

    describe 'due_date' do
      it 'does not apply due_date filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:due_after
            filters:due_before
          ])
      end

      context 'when due_after option is provided' do
        let(:options) { base_options.merge(due_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:due_after])
        end
      end

      context 'when due_before option is provided' do
        let(:options) { base_options.merge(due_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:due_before])
        end
      end

      context 'when both due_after and due_before options are provided' do
        let(:options) { base_options.merge(due_after: '2025-01-01T00:00:00Z', due_before: '2025-12-31T23:59:59Z') }

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:due_after filters:due_before])
        end
      end
    end

    describe 'iids' do
      it 'does not apply iids filter by default' do
        assert_names_in_query(build,
          without: %w[
            filters:iids
          ])
      end

      context 'when iids option is provided with single iid' do
        let(:options) { base_options.merge(iids: [1]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:iids])
        end
      end

      context 'when iids option is provided with multiple iids' do
        let(:options) { base_options.merge(iids: [1, 2, 3]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:iids])
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
