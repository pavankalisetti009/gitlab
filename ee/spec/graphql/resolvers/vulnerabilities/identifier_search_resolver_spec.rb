# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Vulnerabilities::IdentifierSearchResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:search_results) { resolve(described_class, obj: project, args: args, ctx: { current_user: current_user }) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:identifier) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23')
  end

  let_it_be(:identifier_2) do
    create(:vulnerabilities_identifier, project: project_2, external_type: 'cwe', name: 'CWE-24')
  end

  describe '#resolve' do
    let!(:args) { { name: 'cwe' } }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the current user has access' do
      before_all do
        group.add_maintainer(current_user)
      end

      it 'fetches matching identifier names' do
        create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-25')

        expect(search_results).to contain_exactly('CWE-23', 'CWE-25')
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(vulnerability_filtering_by_identifier: false)
        end

        it 'raises an error for the disabled feature flag' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
            'Feature flag `vulnerability_filtering_by_identifier` is disabled for the project.') do
            search_results
          end
        end
      end

      context 'when the name argument is less than 3 characters' do
        let(:args) { { name: 'ab' } }

        it 'raises an error for insufficient name length' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
            'Name should be greater than 3 characters.') do
            search_results
          end
        end
      end
    end

    context 'when the current user does not have access' do
      it 'returns resource not available' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          search_results
        end
      end
    end
  end
end
