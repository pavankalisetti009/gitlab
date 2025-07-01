# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::IndexingService, feature_category: :global_search do
  let_it_be(:repository) { create(:ai_active_context_code_repository, state: :pending) }

  describe '.execute' do
    it 'updates the state' do
      expect { described_class.execute(repository) }.to change {
        repository.reload.state
      }.from('pending').to('code_indexing_in_progress')
    end
  end
end
