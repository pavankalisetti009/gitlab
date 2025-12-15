# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Active Context Code Indexing Integration', :active_context, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }
  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, :ready, active_context_connection: connection)
  end

  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:repository) do
    create(
      :ai_active_context_code_repository,
      state: :pending,
      project: project,
      connection_id: connection.id
    )
  end

  before_all do
    run_active_context_migrations!
  end

  context 'when indexing a project' do
    it 'indexes code chunks' do
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository)

      expect(repository.reload.state).to eq('embedding_indexing_in_progress')
      expect(repository.last_commit).to eq(project.repository.commit.id)
      expect(repository.initial_indexing_last_queued_item).to be_present

      search_result = Ai::ActiveContext::Collections::Code.search(
        user: nil,
        query: ::ActiveContext::Query.filter(project_id: project.id)
      )

      expect(search_result.count).to be > 0
      expect(search_result.first['project_id']).to eq(project.id)
      expect(search_result.first).to have_key('path')
      expect(search_result.first).to have_key('content')
    end
  end
end
