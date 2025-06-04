# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::CodebaseSearch::Executor, feature_category: :duo_chat do
  shared_examples 'tool returns an error' do
    it 'returns an error answer with the expected content' do
      answer = execute_tool
      expect(answer.status).to eq(:error)
      expect(answer.content).to include(answer_message)
    end
  end

  shared_examples 'codebase query is not executed' do
    it 'does not execute the codebase query' do
      expect(::Ai::ActiveContext::Queries::Code).not_to receive(:new)

      execute_tool
    end
  end

  let_it_be(:user) { create(:user) }

  it 'defines NAME' do
    expect(described_class::NAME).to eq('CodebaseSearch')
  end

  describe '#execute', :saas do
    subject(:execute_tool) { described_class.new(context: gitlab_context, options: tool_options).execute }

    let(:user_input) { "dummy user input" }
    let(:additional_context) { [] }

    let(:tool_options) { { input: user_input } }

    let(:gitlab_context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        container: nil,
        resource: nil,
        current_user: user,
        ai_request: nil,
        additional_context: ::CodeSuggestions::Context.new(
          Array.wrap(additional_context)
        ).trimmed
      )
    end

    let(:logger) { instance_double(Gitlab::Llm::Logger, error: nil, info: nil) }

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    end

    context 'when user does not have duo_chat access' do
      it_behaves_like 'codebase query is not executed'

      it_behaves_like 'tool returns an error' do
        let(:answer_message) { "you don't have access to them" }
      end
    end

    context 'when user has duo_chat access' do
      # group is needed for the 'with duo pro addon' included context
      let_it_be(:group) { create(:group, developers: [user]) }

      include_context 'with duo pro addon'

      context 'without repository additional_contexts' do
        it_behaves_like 'codebase query is not executed'

        it 'returns a not_executed answer with the expected content' do
          answer = execute_tool
          expect(answer.status).to eq(:not_executed)

          expected_content = "There are no repository additional contexts. Semantic search was not executed."
          expect(answer.content).to eq(expected_content)
        end
      end

      context 'when repository additional_contexts are given' do
        let_it_be(:project_1) { create(:project, owners: [user]) }
        let_it_be(:project_2) { create(:project, developers: [user]) }

        let(:additional_context) do
          projects = [project_1, project_2]
          projects.map do |p|
            {
              category: 'repository',
              id: "gid://gitlab/Project/#{p.id}",
              content: ''
            }
          end
        end

        let(:codebase_query) { ::Ai::ActiveContext::Queries::Code.new(search_term: user_input, user: user) }

        before do
          allow(::Ai::ActiveContext::Queries::Code).to receive(:new).and_return(codebase_query)
        end

        context 'when a collection record does not exist' do
          let(:expected_error_message) do
            "Error in semantic search: " \
              "#{Ai::ActiveContext::Queries::Code::NoCollectionRecordError} " \
              "A Code collection record is required."
          end

          it_behaves_like 'tool returns an error' do
            let(:answer_message) { expected_error_message }
          end

          it 'is logged as an error' do
            expect(logger).to receive(:error).with(
              message: expected_error_message,
              event_name: 'codebase_search_failed',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )

            execute_tool
          end
        end

        context 'when a collection record exists' do
          before do
            create(
              :ai_active_context_collection,
              name: Ai::ActiveContext::Collections::Code.collection_name,
              search_embedding_version: 1, # see Ai::ActiveContext::Collections::Code::MODELS for details
              include_ref_fields: false
            )

            # mock codebase query, with different results depending on project_id
            allow(codebase_query).to receive(:filter).with(project_id: project_1.id)
              .and_return(build_es_query_result(project_1.id))
            allow(codebase_query).to receive(:filter).with(project_id: project_2.id)
              .and_return(build_es_query_result(project_2.id))
          end

          let(:elasticsearch_docs) do
            {
              project_1.id => [
                build_es_doc_source(project_1, "proj1/file1.txt", "test content 1-1"),
                build_es_doc_source(project_1, "proj1/file2.txt", "test content 1-1")
              ],
              project_2.id => [
                build_es_doc_source(project_2, "proj2/file1.txt", "test content 2-1")
              ]
            }
          end

          def build_es_doc_source(project, file_path, content)
            {
              '_source' => {
                'project_id' => project.id,
                'path' => file_path,
                'content' => content
              }
            }
          end

          def build_es_query_result(project_id)
            es_docs = elasticsearch_docs[project_id]
            return unless es_docs

            es_hits = { 'hits' => { 'total' => { 'value' => 1 }, 'hits' => es_docs } }

            ActiveContext::Databases::Elasticsearch::QueryResult.new(
              result: es_hits,
              collection: Ai::ActiveContext::Collections::Code,
              user: user
            )
          end

          def expected_search_results(global_project_id)
            project_id = global_project_id.split("/").last.to_i
            es_docs = elasticsearch_docs[project_id] || []
            es_docs.pluck('_source')
          end

          it 'returns a successful answer' do
            answer = execute_tool
            expect(answer.status).to eq(:ok)

            expected_message = "The repository additional contexts have been enhanced with semantic search results."
            expect(answer.content).to eq(expected_message)
          end

          it 'enhances the repository additional contexts' do
            execute_tool

            gitlab_context.additional_context.each do |ac|
              ac_content = ac['content']

              expected_message = "A semantic search has been performed on the repository."
              expect(ac_content).to include(expected_message)

              expected_search_results(ac['id']).each do |esr_info|
                expected_search_result = "<search_result>\n" \
                  "<file_path>#{esr_info['path']}</file_path>\n" \
                  "<content>#{esr_info['content']}</content>\n" \
                  "</search_result>"
                expect(ac_content).to include(expected_search_result)
              end
            end
          end

          it 'logs the semantic search request events' do
            expect(logger).to receive(:info).with(
              message: a_string_matching(/Requesting semantic search/),
              event_name: 'codebase_search_requesting',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )
            expect(logger).to receive(:info).with(
              message: a_string_matching(/Semantic search requested/),
              event_name: 'codebase_search_requested',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )

            execute_tool
          end

          context 'when there is an error in the semantic search' do
            before do
              allow(codebase_query).to receive(:filter).and_raise(
                StandardError, raised_error_message
              )
            end

            let(:raised_error_message) { "cannot search the vector store" }
            let(:expected_error_message) { "Error in semantic search: StandardError #{raised_error_message}" }

            it_behaves_like 'tool returns an error' do
              let(:answer_message) { expected_error_message }
            end

            it 'logs the correct events' do
              expect(logger).to receive(:info).with(
                message: a_string_matching(/Requesting semantic search/),
                event_name: 'codebase_search_requesting',
                unit_primitive: 'codebase_search',
                ai_component: 'duo_chat',
                klass: anything
              )
              expect(logger).to receive(:error).with(
                message: expected_error_message,
                event_name: 'codebase_search_failed',
                unit_primitive: 'codebase_search',
                ai_component: 'duo_chat',
                klass: anything
              )

              execute_tool
            end
          end
        end
      end
    end
  end
end
