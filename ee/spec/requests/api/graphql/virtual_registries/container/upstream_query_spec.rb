# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a container virtual registry', :aggregate_failures, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group, registries: [registry]) }
  let_it_be(:cache_entries) { create_list(:virtual_registries_container_cache_remote_entry, 2, upstream:) }

  let(:global_id) { upstream.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        virtualRegistriesContainerUpstream(id: "#{global_id}") {
          id
          url
          cacheValidityHours
          username
          name
          description
          registriesCount
          registryUpstreams {
            position
            registry {
              name
            }
          }
          cacheEntries {
            count
            nodes {
              id
            }
          }
        }
      }
    GRAPHQL
  end

  let(:container_upstream_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['virtualRegistriesContainerUpstream']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for virtualRegistriesContainerUpstream' do
    it 'returns null for the virtualRegistriesContainerUpstream field' do
      expect(container_upstream_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesContainerUpstream'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesContainerUpstream'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      context 'when upstream exists' do
        it 'returns upstream for the containerVirtualRegistry field' do
          expect(container_upstream_response['name']).to eq(upstream.name)
        end

        it 'returns registry upstreams with registry information' do
          registry_upstreams = container_upstream_response['registryUpstreams']
          expect(registry_upstreams.length).to be 1
          expect(registry_upstreams[0]['position']).to be 1
          expect(registry_upstreams[0]['registry']).to include('name' => registry.name)
        end
      end

      it 'returns cache entries and count' do
        expect(container_upstream_response['cacheEntries']['count']).to eq(2)
        expect(container_upstream_response['cacheEntries']['nodes'].pluck('id'))
            .to match_array(cache_entries.map(&:generate_id))
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

          create(:virtual_registries_container_registry, group: group, upstreams: [upstream], name: 'registry 2')

          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control_count)
          expect_graphql_errors_to_be_empty
        end

        it 'returns correct registriesCount for upstream with multiple registries' do
          create(:virtual_registries_container_registry, group: group, upstreams: [upstream],
            name: 'registry 2')
          create(:virtual_registries_container_registry, group: group, upstreams: [upstream],
            name: 'registry 3')

          query = <<~GRAPHQL
            {
              virtualRegistriesContainerUpstream(id: "#{global_id}") {
                registriesCount
                registryUpstreams {
                  registry {
                    id
                  }
                }
              }
            }
          GRAPHQL

          post_graphql(query, current_user: current_user)
          expect(graphql_data['virtualRegistriesContainerUpstream']['registryUpstreams'].length).to eq(3)
          expect(graphql_data['virtualRegistriesContainerUpstream']['registriesCount']).to eq(3)
          expect_graphql_errors_to_be_empty
        end
      end

      context 'when upstream does not exist' do
        let(:global_id) { "gid://gitlab/VirtualRegistries::Container::Upstream/#{non_existing_record_id}" }

        it_behaves_like 'returns null for virtualRegistriesContainerUpstream'
      end
    end
  end
end
