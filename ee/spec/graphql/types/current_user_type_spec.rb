# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::CurrentUserType, feature_category: :user_profile do
  it 'has the expected fields' do
    expected_fields = %w[
      workspaces
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'workspaces field' do
    subject { described_class.fields['workspaces'] }

    it 'returns workspaces' do
      is_expected.to have_graphql_type(Types::RemoteDevelopment::WorkspaceType.connection_type)
      is_expected.to have_graphql_resolver(Resolvers::RemoteDevelopment::WorkspacesResolver)
    end
  end
end
