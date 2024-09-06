# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.epss', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }

  let_it_be(:fields) do
    <<~QUERY
      epss {
        cve
        score
      }
    QUERY
  end

  let_it_be(:query) do
    graphql_query_for('vulnerabilities', {}, query_graphql_field('nodes', {}, fields))
  end

  let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: :container_scanning) }

  let_it_be(:epss) { create(:pm_epss) }
  let_it_be(:identifier) do
    create(:vulnerabilities_identifier, external_type: 'cve', external_id: epss.cve, name: epss.cve)
  end

  let_it_be(:finding) do
    create(
      :vulnerabilities_finding,
      vulnerability: vulnerability,
      identifiers: [identifier]
    )
  end

  subject(:data) { graphql_data.dig('vulnerabilities', 'nodes') }

  before_all do
    project.add_developer(user)
  end

  context 'when feature flag is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(epss_querying: true)
    end

    it 'returns epss data' do
      post_graphql(query, current_user: user)

      result = data.first['epss']

      expect(result['cve']).to eq(epss.cve)
      expect(result['score']).to eq(epss.score)
    end

    it 'returns nil for non-cve identifier' do
      non_cve_identifier = create(
        :vulnerabilities_identifier,
        external_type: 'non-cve',
        external_id: 'non-cve',
        name: 'non-cve')

      non_cve_vuln = create(:vulnerability, project: project, report_type: :container_scanning)

      create(
        :vulnerabilities_finding,
        vulnerability: non_cve_vuln,
        identifiers: [non_cve_identifier]
      )

      post_graphql(query, current_user: user)

      expect(data).to contain_exactly(
        { "epss" => nil },
        { "epss" => { "cve" => epss.cve, "score" => epss.score } }
      )
    end

    it 'does not have N+1 queries' do
      # warm up
      post_graphql(query, current_user: user)

      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }

      new_vuln = create(:vulnerability, project: project, report_type: :container_scanning)

      new_cve = "CVE-2020-1234"
      create(
        :vulnerabilities_finding,
        vulnerability: new_vuln,
        identifiers: [create(:vulnerabilities_identifier, external_type: 'cve', external_id: new_cve, name: new_cve)]
      )

      expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(epss_querying: false)
    end

    it 'returns nil for epss data' do
      post_graphql(query, current_user: user)

      expect(data).to contain_exactly(
        { "epss" => nil }
      )
    end
  end
end
