# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a maven upstream registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry') }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let(:global_id) { upstream.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        mavenUpstreamRegistry(id: "#{global_id}") {
          id
          name
          registries {
            nodes {
              id
              name
            }
          }
        }
      }
    GRAPHQL
  end

  let(:maven_upstream_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['mavenUpstreamRegistry']
  end

  shared_examples 'returns null for mavenUpstreamRegistry' do
    it 'returns null for the mavenUpstreamRegistry field' do
      expect(maven_upstream_response).to be_nil
    end
  end

  before do
    setup_default_configuration
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for mavenUpstreamRegistry'
  end

  context 'when user has access' do
    before do
      group.add_member(current_user, Gitlab::Access::GUEST)
    end

    context 'when upstream exists' do
      it 'returns upstream for the mavenUpstreamRegistry field' do
        expect(maven_upstream_response['name']).to eq('name')
      end

      it 'returns registries for the mavenUpstreamRegistry field' do
        expect(maven_upstream_response['registries']['nodes'][0]['name']).to eq('test registry')
      end

      context 'when dependency proxy config is disabled' do
        before do
          stub_config(dependency_proxy: { enabled: false })
        end

        it_behaves_like 'returns null for mavenUpstreamRegistry'
      end

      context 'when licensed feature packages_virtual_registry is disabled' do
        before do
          stub_licensed_features(packages_virtual_registry: false)
        end

        it_behaves_like 'returns null for mavenUpstreamRegistry'
      end

      context 'with the maven virtual registry feature flag turned off' do
        before do
          stub_feature_flags(maven_virtual_registry: false)
        end

        it_behaves_like 'returns null for mavenUpstreamRegistry'
      end
    end

    context 'when upstream does not exist' do
      let(:global_id) { "gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/#{non_existing_record_id}" }

      it_behaves_like 'returns null for mavenUpstreamRegistry'
    end
  end

  private

  def setup_default_configuration
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end
end
