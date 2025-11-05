# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queries::Code, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let(:search_term) { 'dummy search term' }

  subject(:codebase_query) { described_class.new(search_term: search_term, user: user) }

  describe '.available?' do
    subject(:available) { described_class.available? }

    context 'when Code indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when Code indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'when code collection record does not exist' do
        it { is_expected.to be(false) }
      end

      context 'when code collection record exists' do
        before do
          create(
            :ai_active_context_collection,
            name: Ai::ActiveContext::Collections::Code.collection_name,
            search_embedding_version: 1,
            include_ref_fields: false
          )
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#filter' do
    context 'when semantic search is not available' do
      let(:expected_error_class) { Ai::ActiveContext::Queries::Code::NotAvailable }

      it 'raises the expected error' do
        expect { codebase_query.filter(project_id: 123) }.to raise_error(
          expected_error_class, "Semantic search on Code collection is not available."
        )
      end
    end

    context 'when semantic search is available' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)

        # mock the call to embeddings generation
        allow(ActiveContext::Embeddings).to receive(:generate_embeddings)
          .with(
            search_term,
            unit_primitive: 'generate_embeddings_codebase',
            version: embeddings_version_details
          ).and_return([target_embeddings])

        # mock code collections search, with different results depending on project_id
        allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
          project_id = args[:query].children.first.children.first.value[:project_id]

          es_docs = elasticsearch_docs[project_id]
          build_es_query_result(es_docs)
        end
      end

      # We get the embeddings version and details from Ai::ActiveContext::Collections::Code::MODELS
      let_it_be(:embeddings_version) { 1 }
      let_it_be(:embeddings_version_details) { Ai::ActiveContext::Collections::Code::MODELS[embeddings_version] }

      let_it_be(:collection) do
        create(
          :ai_active_context_collection,
          name: Ai::ActiveContext::Collections::Code.collection_name,
          search_embedding_version: embeddings_version,
          include_ref_fields: false
        )
      end

      let_it_be(:group) { create(:group) }
      let_it_be(:enabled_namespace) do
        create(
          :ai_active_context_code_enabled_namespace,
          :ready,
          namespace: group,
          active_context_connection: collection.connection
        )
      end

      let_it_be(:project) do
        create(:project, group: group, owners: [user]).tap do |p|
          attach_active_context_repository(project: p, collection: collection, enabled_namespace: enabled_namespace)
        end
      end

      let_it_be(:project_2) do
        create(:project, group: group, developers: [user]).tap do |p|
          attach_active_context_repository(project: p, collection: collection, enabled_namespace: enabled_namespace)
        end
      end

      let(:target_embeddings) { [1, 2, 3] }

      let(:elasticsearch_docs) do
        {
          project.id => [
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content 1-1",
                'path' => 'some/path/to/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d1::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              }
            },
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content 1-2",
                'path' => 'some/path/to/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5910d1::600:546::10',
                'embeddings_v1' => Array.new(768, 0.0)
              }
            }
          ],
          project_2.id => [
            {
              '_source' => {
                'id' => 2,
                'project_id' => project_2.id,
                'content' => "test content 2-1",
                'path' => 'some/path/to/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5911d1::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              }
            }
          ]
        }
      end

      it 'generates embeddings only once for multiple filters' do
        expect(ActiveContext::Embeddings).to receive(:generate_embeddings).once

        codebase_query.filter(project_id: project.id)
        codebase_query.filter(project_id: project_2.id)
      end

      it 'calls a search on the Code collection class for each filter' do
        expect(::Ai::ActiveContext::Collections::Code).to receive(:search).twice

        codebase_query.filter(project_id: project.id)
        codebase_query.filter(project_id: project_2.id)
      end

      it 'returns the expected results' do
        project_1_result = codebase_query.filter(project_id: project.id)
        expect(project_1_result.success?).to be(true)
        expect(project_1_result.to_a).to eq(elasticsearch_docs[project.id].pluck('_source'))

        project_2_result = codebase_query.filter(project_id: project_2.id)
        expect(project_2_result.success?).to be(true)
        expect(project_2_result.to_a).to eq(elasticsearch_docs[project_2.id].pluck('_source'))
      end

      describe 'setting last_queried_at', :freeze_time do
        before do
          ac_repository.update!(last_queried_at: nil)
        end

        let(:ac_repository) { project.ready_active_context_code_repository }

        it 'updates the last queried timestamp of the active_context repository records', :freeze_time do
          expect { codebase_query.filter(project_id: project.id) }
            .to change { ac_repository.reload.last_queried_at }.to(Time.current)
            .and not_change { project_2.reload.ready_active_context_code_repository.last_queried_at }
        end

        context 'when the last_queried_at of the active context repository record is already set' do
          context 'when last_queried_at is earlier than 1 hour ago' do
            before do
              ac_repository.update!(last_queried_at: Time.current - 2.hours)
            end

            it 'updates the last_queried_at', :freeze_time do
              expect { codebase_query.filter(project_id: project.id) }
                .to change { ac_repository.reload.last_queried_at }.to(Time.current)
                .and not_change { project_2.reload.ready_active_context_code_repository.last_queried_at }
            end
          end

          context 'when last_queried_at is later than 1 hour ago' do
            before do
              ac_repository.update!(last_queried_at: Time.current - 30.minutes)
            end

            it 'does not update the last_queried_at' do
              expect { codebase_query.filter(project_id: project.id) }
                .not_to change { ac_repository.reload.last_queried_at }
            end
          end
        end

        context 'when there is an error updating last_queried_at' do
          before do
            allow(ac_repository).to receive(:update_last_queried_timestamp).and_raise(
              ActiveRecord::ActiveRecordError, "There is an error"
            )

            allow(Ai::ActiveContext::Code::Repository).to receive(:find_by)
              .with(hash_including(project_id: project.id)).and_return(ac_repository)

            allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
          end

          let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, warn: nil) }

          it 'catches the error and logs it' do
            expect(logger).to receive(:warn).with({
              "class" => "Ai::ActiveContext::Queries::Code",
              "message" => "Failed to update last_queried_at",
              "exception_class" => "ActiveRecord::ActiveRecordError",
              "exception_message" => "There is an error",
              "ai_active_context_code_repository_id" => ac_repository.id,
              "project_id" => project.id
            })

            expect { codebase_query.filter(project_id: project.id) }.not_to raise_error
          end
        end
      end

      context 'when exclude_fields and extract_source_segments is provided' do
        it 'returns the expected results' do
          project_1_result = codebase_query.filter(
            project_id: project.id,
            exclude_fields: %w[id source type embeddings_v1 reindexing],
            extract_source_segments: true
          )

          expect(project_1_result.success?).to be(true)

          expect(project_1_result).to match_array([
            {
              'project_id' => project.id,
              'path' => 'some/path/to/test.rb',
              'name' => 'test.rb',
              'language' => 'ruby',
              'content' => "test content 1-1",
              'blob_id' => "a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d1",
              'start_byte' => 0,
              'length' => 546,
              'start_line' => 0
            },
            {
              'project_id' => project.id,
              'path' => 'some/path/to/test.rb',
              'name' => 'test.rb',
              'language' => 'ruby',
              'content' => "test content 1-2",
              'blob_id' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5910d1',
              'start_byte' => 600,
              'length' => 546,
              'start_line' => 10
            }
          ])
        end
      end

      context 'when filtering by path' do
        let(:project_es_docs_in_path) do
          [
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content in path",
                'path' => 'some/path/to/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              }
            }
          ]
        end

        it 'passes the correct query parameters to search and returns the expected results' do
          allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
            and_query = args[:query].children.first.children.first.children
            first_query = and_query.first
            second_query = and_query.second

            expect(first_query.type).to eq(:filter)
            expect(first_query.value).to eq({ project_id: project.id })

            expect(second_query.type).to eq(:prefix)
            expect(second_query.value).to eq({ path: 'some/path/' })

            # make sure to return query results
            build_es_query_result(project_es_docs_in_path)
          end

          result = codebase_query.filter(project_id: project.id, path: 'some/path')
          expect(result.success?).to be(true)
          expect(result.each.to_a).to eq(project_es_docs_in_path.pluck('_source'))
        end
      end

      context 'when a project has no code embeddings' do
        shared_examples 'returns no code embeddings error result' do
          it 'returns a result with the expected error_code and error_message' do
            expect(result.success?).to be_falsey
            expect(result.error_code).to eq(Ai::ActiveContext::Queries::Result::ERROR_NO_EMBEDDINGS)

            expect(result.error_message(target_class: Project, target_id: project_id)).to eq(
              "Project '#{project_id}' has no embeddings - #{expected_error_detail}"
            )
          end
        end

        let(:result) { codebase_query.filter(project_id: project_id) }

        context 'when project has no ActiveContext repository record' do
          before do
            project.reload.ready_active_context_code_repository.destroy!

            allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).and_return(true)
          end

          let(:project_id) { project.id }

          it 'prioritizes cached value when checking eligibility' do
            expect(Rails.cache).to receive(:fetch).with(
              "active_context_code_eligible_project_#{project.id}",
              expires_in: described_class::CODE_ELIGIBILITY_CACHE_EXPIRY,
              force: false
            ).and_call_original

            result
          end

          it 'triggers ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).with(project.id)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_STARTED }
          end

          context 'when triggering the ad-hoc indexing worker returns a falsey value' do
            before do
              allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async)
                .and_return(nil)
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED }
            end
          end

          context 'when ad-hoc indexing attempt fails' do
            before do
              allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async)
                .and_raise(StandardError, "There is an error")

              allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
            end

            let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, warn: nil) }

            it 'logs the error' do
              expect(logger).to receive(:warn).with({
                "class" => "Ai::ActiveContext::Queries::Code",
                "message" => "Failed to trigger ad-hoc indexing",
                "exception_class" => "StandardError",
                "exception_message" => "There is an error",
                "project_id" => project_id
              })

              result
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED }
            end
          end

          context 'when not eligible for code embeddings' do
            shared_examples 'returns an error result with "use another source" message' do
              it_behaves_like 'returns no code embeddings error result' do
                let(:expected_error_detail) { described_class::MESSAGE_USE_ANOTHER_SOURCE }
              end
            end

            context 'when project does not exist' do
              let(:project_id) { 0 }

              it_behaves_like 'returns an error result with "use another source" message'
            end

            context 'when `active_context_code_index_project` is disabled' do
              before do
                stub_feature_flags(active_context_code_index_project: false)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end

            context 'when project has duo_features_enabled setting = false' do
              before do
                project.project_setting.update!(duo_features_enabled: false)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end

            context 'when project has no enabled namespace' do
              before do
                enabled_namespace.reload.update!(state: :pending)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end
          end
        end

        context 'when project has a failed ActiveContext repository record' do
          before do
            project_2.reload.ready_active_context_code_repository.failed!
          end

          let(:project_id) { project_2.id }

          it 'does not trigger ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INDEXING_FAILED }
          end
        end

        context 'when project has a non-ready and not failed ActiveContext repository record' do
          before do
            project_2.reload.ready_active_context_code_repository.pending!
          end

          let(:project_id) { project_2.id }

          it 'does not trigger ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_ONGOING }
          end
        end
      end
    end
  end

  def attach_active_context_repository(project:, collection:, enabled_namespace:)
    create(
      :ai_active_context_code_repository,
      :ready,
      project: project,
      enabled_namespace: enabled_namespace,
      connection_id: collection.connection_id
    )
  end

  def build_es_query_result(es_docs)
    return unless es_docs

    es_hits = { 'hits' => { 'total' => { 'value' => 1 }, 'hits' => es_docs } }

    ActiveContext::Databases::Elasticsearch::QueryResult.new(
      result: es_hits,
      collection: Ai::ActiveContext::Collections::Code,
      user: user
    )
  end
end
