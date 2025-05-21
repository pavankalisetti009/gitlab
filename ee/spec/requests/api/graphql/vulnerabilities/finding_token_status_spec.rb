# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerability.findingTokenStatus', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let(:vuln_gid) { vulnerability.to_global_id.to_s }
  let(:current_user) { user }
  let(:query) do
    <<~GQL
      query($id: VulnerabilityID!) {
        vulnerability(id: $id) {
          findingTokenStatus {
            id
            status
            createdAt
            updatedAt
          }
        }
      }
    GQL
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: vuln_gid })
  end

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  shared_examples 'returns no token status' do
    it_behaves_like 'a working graphql query that returns data'

    it 'has a nil findingTokenStatus' do
      expect(graphql_data.dig('vulnerability', 'findingTokenStatus')).to be_nil
    end
  end

  context 'when the validity_checks feature flag is disabled' do
    before_all do
      project.add_developer(user)
    end

    before do
      stub_feature_flags(validity_checks: false)
      post_query
    end

    it_behaves_like 'returns no token status'
  end

  context 'when the validity_checks feature flag is enabled' do
    before do
      stub_feature_flags(validity_checks: true)
    end

    context 'when vulnerability has no finding' do
      let(:vulnerability) { create(:vulnerability, project: project) }

      it_behaves_like 'returns no token status' do
        before do
          post_query
        end
      end
    end

    context 'when there is a finding' do
      before do
        create(:vulnerabilities_finding, vulnerability: vulnerability)
      end

      context 'when there is no token status' do
        it_behaves_like 'returns no token status' do
          before do
            post_query
          end
        end
      end

      context 'when there is a token status' do
        let_it_be(:finding) do
          create(
            :vulnerabilities_finding,
            :with_token_status,
            token_status: :active,
            vulnerability: vulnerability
          )
        end

        before do
          post_query
        end

        it_behaves_like 'a working graphql query that returns data'

        it 'returns the correct token status object' do
          node = graphql_data.dig('vulnerability', 'findingTokenStatus')

          expect(node['status']).to eq('ACTIVE')
        end
      end
    end
  end
end
