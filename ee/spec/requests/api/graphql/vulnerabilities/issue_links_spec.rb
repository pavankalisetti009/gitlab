# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.issueLinks', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:created_issue) { create(:issue, project: project) }
  let_it_be(:related_issue) { create(:issue, project: project) }
  let_it_be(:related_issue_link) { create(:vulnerabilities_issue_link, :related, vulnerability: vulnerability, issue: related_issue) }
  let_it_be(:created_issue_link) { create(:vulnerabilities_issue_link, :created, vulnerability: vulnerability, issue: created_issue) }

  before do
    project.add_developer(user)

    stub_licensed_features(security_dashboard: true)
  end

  context 'when invalid linkType argument is provided' do
    it 'errors with a string' do
      query_issue_links('"created"')

      expect(graphql_errors).to include(a_hash_including('message' => "Argument 'linkType' on Field 'issueLinks' has an invalid value (\"created\"). Expected type 'VulnerabilityIssueLinkType'."))
    end

    it 'errors with a number' do
      query_issue_links(1)

      expect(graphql_errors).to include(a_hash_including('message' => "Argument 'linkType' on Field 'issueLinks' has an invalid value (1). Expected type 'VulnerabilityIssueLinkType'."))
    end

    it 'errors with lowercased `created`' do
      query_issue_links('created')

      expect(graphql_errors).to include(a_hash_including('message' => "Argument 'linkType' on Field 'issueLinks' has an invalid value (created). Expected type 'VulnerabilityIssueLinkType'."))
    end

    it 'errors with lowercased `related`' do
      query_issue_links('related')

      expect(graphql_errors).to include(a_hash_including('message' => "Argument 'linkType' on Field 'issueLinks' has an invalid value (related). Expected type 'VulnerabilityIssueLinkType'."))
    end
  end

  context 'when valid linkType argument is provided' do
    it 'returns a list of VulnerabilityIssueLink with `CREATED` linkType' do
      query_issue_links('CREATED')

      expect_issue_links_response(created_issue_link)
    end

    it 'returns a list of VulnerabilityIssueLink with `RELATED` linkType' do
      query_issue_links('RELATED')

      expect_issue_links_response(related_issue_link)
    end
  end

  context 'when no arguments are provided' do
    it 'returns a list of all VulnerabilityIssueLink' do
      query_issue_links

      expect_issue_links_response(related_issue_link, created_issue_link)
    end
  end

  describe 'loading issue links in batch' do
    before do
      create(:organization)
      create(:vulnerability, :with_finding, project: project)
    end

    it 'does not cause N+1 query issue' do
      query_issue_links # Calling this the first time issues more queries

      # 1) Select personal access tokens
      # 2) Savepoint
      # 3) Insert into personal access tokens
      # 4) Release savepoint
      # 5) Select personal access tokens
      # 6) Select current organization
      # 7) Select geo nodes
      # 8) Update personal access tokens(last used at)
      # 9) Select user
      # 10) Select user_detail
      # 11) Authorization check
      # 12) Select vulnerability_reads
      # 13) Select vulnerabilities
      # 14) Select project
      # 15) Select route
      # 16) Select vulnerability occurrences
      # 17) Select vulnerability reads
      # 18) Select vulnerability scanners
      # 19) Select vulnerability identifiers join table
      # 20) Select vulnerability identifiers
      # 21) Select namespace
      # 22) Select group links
      # 23) Select project features
      # 24) Authorization check
      # 25) Select issue links
      # 26) Select issues
      # 27) Select issue project
      # 28) Loading the project authorizations
      # 29) Loading the namespace
      # 30) Loading the user
      # 31) Loading the organization
      # 32) Loading the organization for access token (only inside specs)
      # 33) Loading the organization_details for avatar_url
      # 34/35) Likely transitional in nature during decomposition. Investigate when all tables are transitioned
      # 36) Load last used IPs of personal access tokens
      # 37) Saver current IP of the request in personal access token last used IPs
      # https://gitlab.com/gitlab-org/gitlab/-/issues/480882
      expect { query_issue_links }.not_to exceed_query_limit(37)
    end
  end

  def query_issue_links(link_type = nil)
    query = graphql_query_for('vulnerabilities', {}, query_graphql_field('nodes', {}, create_fields(link_type)))
    post_graphql(query, current_user: user)
  end

  def create_fields(link_type)
    if link_type.nil?
      <<~QUERY
        issueLinks {
          nodes {
            id
          }
        }
      QUERY
    else
      <<~QUERY
        issueLinks (linkType: #{link_type}) {
          nodes {
            id
          }
        }
      QUERY
    end
  end

  def expect_issue_links_response(*issue_links)
    actual_issue_links = graphql_data['vulnerabilities']['nodes'].map do |vulnerability|
      vulnerability["issueLinks"]["nodes"].map { |issue_link| issue_link['id'] }
    end
    expected_issue_links = issue_links.map { |issue_link| issue_link.to_global_id.to_s }

    expect(actual_issue_links.flatten).to contain_exactly(*expected_issue_links)
    expect(graphql_errors).to be_nil
  end
end
