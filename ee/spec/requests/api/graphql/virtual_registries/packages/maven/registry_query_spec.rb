# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a maven virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams, group: group) }

  let(:global_id) { registry.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        mavenVirtualRegistry(id: "#{global_id}") {
          id
          name
          upstreams {
            id
            registries {
              nodes {
                id
                name
              }
            }
            registryUpstreams {
              id
              position
              registry {
                name
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:maven_registry_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['mavenVirtualRegistry']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for mavenVirtualRegistry' do
    it 'returns null for the mavenVirtualRegistry field' do
      expect(maven_registry_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for mavenVirtualRegistry'
  end

  context 'when user has access' do
    before do
      group.add_member(current_user, Gitlab::Access::GUEST)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for mavenVirtualRegistry'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      context 'when registry exists' do
        it 'returns registry for the mavenVirtualRegistry field' do
          expect(maven_registry_response['name']).to eq('name')
        end

        it 'returns registry upstreams for an upstream' do
          upstreams = maven_registry_response['upstreams']
          registry_upstreams = upstreams[0]['registryUpstreams']

          expect(registry_upstreams.length).to be 1
          expect(registry_upstreams[0]['position']).to be 1
        end
      end

      context 'when multiple upstreams exist' do
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

          registry1 = create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry1')
          create(:virtual_registries_packages_maven_upstream, registries: [registry, registry1], name: 'test upstream1')

          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control_count)
          expect_graphql_errors_to_be_empty
        end
      end

      context 'when registry does not exist' do
        let(:global_id) { "gid://gitlab/VirtualRegistries::Packages::Maven::Registry/#{non_existing_record_id}" }

        it_behaves_like 'returns null for mavenVirtualRegistry'
      end
    end
  end
end
