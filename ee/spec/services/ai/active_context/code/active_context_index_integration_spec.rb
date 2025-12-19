# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Active Context Code Indexing Integration', :active_context, feature_category: :global_search do
  context 'with Elasticsearch', :elasticsearch_adapter do
    let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }

    it_behaves_like 'active context code indexing integration'
  end

  context 'with OpenSearch', :opensearch_adapter do
    let_it_be(:connection) { create(:ai_active_context_connection, :opensearch) }

    it_behaves_like 'active context code indexing integration'
  end
end
