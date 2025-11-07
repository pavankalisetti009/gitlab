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
          registriesCount
          registryUpstreams {
            id
            position
            registry {
              name
            }
          }
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

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for mavenUpstreamRegistry' do
    it 'returns null for the mavenUpstreamRegistry field' do
      expect(maven_upstream_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for mavenUpstreamRegistry'
  end

  context 'when user has access' do
    before do
      group.add_member(current_user, Gitlab::Access::GUEST)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for mavenUpstreamRegistry'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      context 'when upstream exists' do
        it 'returns upstream for the mavenUpstreamRegistry field' do
          expect(maven_upstream_response['name']).to eq('name')
        end

        it 'returns registries count for the mavenUpstreamRegistry field' do
          expect(maven_upstream_response['registriesCount']).to eq(1)
        end

        it 'returns registries for the mavenUpstreamRegistry field' do
          expect(maven_upstream_response['registries']['nodes'][0]['name']).to eq('test registry')
        end

        context 'when multiple registries exist' do
          let_it_be(:first_user) { create(:user) }
          let_it_be(:second_user) { create(:user) }

          before_all do
            group.add_guest(first_user)
            group.add_guest(second_user)
          end

          it 'avoids N+1 queries' do
            control_count = ActiveRecord::QueryRecorder.new do
              post_graphql(query, current_user: first_user)
            end

            create(:virtual_registries_packages_maven_registry, group: upstream.group, name: 'other').tap do |registry|
              create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:)
            end

            create(:virtual_registries_packages_maven_registry, group: upstream.group, name: 'test').tap do |registry|
              create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:)
            end

            expect do
              post_graphql(query, current_user: second_user)
            end.not_to exceed_query_limit(control_count)
            expect_graphql_errors_to_be_empty
          end
        end
      end

      context 'when upstream does not exist' do
        let(:global_id) { "gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/#{non_existing_record_id}" }

        it_behaves_like 'returns null for mavenUpstreamRegistry'
      end
    end
  end
end
