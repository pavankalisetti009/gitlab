# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).vulnerabilities', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:security_scan) { create(:security_scan, pipeline: pipeline) }
  let_it_be(:security_finding) do
    create(:security_finding,
      scan: security_scan,
      uuid: vulnerability.finding.uuid,
      severity: :high)
  end

  let_it_be(:flag) { create :vulnerabilities_flag, finding: vulnerability.finding }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          vulnerabilities {
            nodes {
              id
              severity
              flags {
                nodes {
                  id
                  status
                  description
                  confidenceScore
                  origin
                  createdAt
                  updatedAt
                }
              }
              latestFlag {
                id
                status
                description
                confidenceScore
                origin
                createdAt
                updatedAt
              }
              latestSecurityReportFinding {
                uuid
                severity
                originalSeverity
              }
            }
          }
        }
      }
    )
  end

  let(:vulnerabilities) { req.dig('project', 'vulnerabilities', 'nodes') }

  subject(:req) do
    post_graphql(query, current_user: user)
    graphql_data
  end

  context 'when the required features are enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user has the correct permissions' do
      before_all do
        project.add_developer(user)
        # flag.update! origin: 'duo' # force updated_at
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_security_resource, anything).and_return(true)
      end

      it 'returns vulnerabilities with security findings' do
        expect(vulnerabilities).not_to be_blank
        expect(vulnerabilities.first['latestSecurityReportFinding']).not_to be_nil
      end

      it 'returns all the queried fields', :aggregate_failures do
        vulnerability_data = vulnerabilities.first

        expect(vulnerability_data['id']).not_to be_nil
        expect(vulnerability_data['severity']).not_to be_nil

        finding = vulnerability_data['latestSecurityReportFinding']
        expect(finding['uuid']).not_to be_nil
        expect(finding['severity']).not_to be_nil
        expect(finding['originalSeverity']).not_to be_nil

        flag_data = vulnerability_data['flags']['nodes'].first
        expect(flag_data['id']).not_to be_nil
        expect(flag_data['status']).not_to be_nil
        expect(flag_data['confidenceScore']).not_to be_nil
        expect(flag_data['origin']).not_to be_nil
        expect(flag_data['createdAt']).not_to be_nil
        expect(flag_data['updatedAt']).not_to be_nil

        latest_flag = vulnerability_data['latestFlag']
        expect(latest_flag['id']).not_to be_nil
        expect(latest_flag['status']).not_to be_nil
        expect(latest_flag['confidenceScore']).not_to be_nil
        expect(latest_flag['origin']).not_to be_nil
        expect(latest_flag['createdAt']).not_to be_nil
        expect(latest_flag['updatedAt']).not_to be_nil
      end
    end

    context 'when user is not a member of the project' do
      let(:non_member_user) { create(:user) }

      subject(:req) do
        post_graphql(query, current_user: non_member_user)
        graphql_data
      end

      it 'returns no vulnerabilities' do
        expect(vulnerabilities).to be_blank
      end
    end
  end

  context 'when the required features are disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it 'returns no vulnerabilities' do
      expect(vulnerabilities).to be_blank
    end
  end
end
