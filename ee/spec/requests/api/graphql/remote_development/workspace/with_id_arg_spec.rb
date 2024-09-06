# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared'

RSpec.describe 'Query.workspace(id: RemoteDevelopmentWorkspaceID!)', feature_category: :workspaces do
  include GraphqlHelpers

  # NOTE: Even though this single-workspace spec only has one field scenario to test, we still use the same
  #       shared examples patterns and structure as the other multi-workspace query specs, for consistency.

  RSpec.shared_context 'for a Query.workspace query' do
    include_context "with authorized user as developer on workspace's project"

    let(:fields) do
      <<~QUERY
        #{all_graphql_fields_for('workspace'.classify, max_depth: 1)}
      QUERY
    end

    let(:query) { graphql_query_for('workspace', args, fields) }

    subject { graphql_data['workspace'] }
  end

  include_context 'with id arg'
  include_context 'for a Query.workspace query'

  context 'with non-admin user' do
    let_it_be(:authorized_user) { workspace.user }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'single workspace query'
  end

  context 'with admin user' do
    let_it_be(:authorized_user) { create(:admin) }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'single workspace query', authorized_user_is_admin: true
  end
end
