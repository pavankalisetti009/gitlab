# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven Virtual Registries (JavaScript fixtures)', feature_category: :virtual_registry do
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) do
    create(:virtual_registries_packages_maven_upstream, registries: [registry], metadata_cache_validity_hours: 48)
  end

  describe GraphQL::Query, type: :request do
    base_path = 'packages_and_registries/virtual_registries/graphql/queries'
    get_maven_upstream_summary_query_path = "#{base_path}/get_maven_upstream_summary.query.graphql"

    let(:query) { get_graphql_query_as_string(get_maven_upstream_summary_query_path, ee: true) }
    let(:variables) { { id: upstream.to_gid.to_s } }

    before_all do
      group.add_guest(user)
    end

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(packages_virtual_registry: true)
    end

    it "ee/graphql/#{get_maven_upstream_summary_query_path}.json" do
      post_graphql(query, current_user: user, variables: variables)

      expect_graphql_errors_to_be_empty
    end
  end
end
