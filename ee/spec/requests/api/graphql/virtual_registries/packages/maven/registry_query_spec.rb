# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a maven virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:global_id) { registry.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        mavenVirtualRegistry(id: "#{global_id}") {
          id
          name
        }
      }
    GRAPHQL
  end

  let(:maven_registry_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['mavenVirtualRegistry']
  end

  shared_examples 'returns null for mavenVirtualRegistry' do
    it 'returns null for the mavenVirtualRegistry field' do
      expect(maven_registry_response).to be_nil
    end
  end

  before do
    setup_default_configuration
  end

  context 'when user does not have access' do
    it 'returns null for the mavenVirtualRegistry field' do
      expect(maven_registry_response).to be_nil
    end
  end

  context 'when user has access' do
    before do
      group.add_member(current_user, Gitlab::Access::GUEST)
    end

    context 'when registry exists' do
      it 'returns registry for the mavenVirtualRegistry field' do
        expect(maven_registry_response['name']).to eq('name')
      end

      context 'when dependency proxy config is disabled' do
        before do
          stub_config(dependency_proxy: { enabled: false })
        end

        it_behaves_like 'returns null for mavenVirtualRegistry'
      end

      context 'when licensed feature packages_virtual_registry is disabled' do
        before do
          stub_licensed_features(packages_virtual_registry: false)
        end

        it_behaves_like 'returns null for mavenVirtualRegistry'
      end

      context 'with the maven virtual registry feature flag turned off' do
        before do
          stub_feature_flags(maven_virtual_registry: false)
        end

        it_behaves_like 'returns null for mavenVirtualRegistry'
      end
    end

    context 'when registry does not exist' do
      let(:global_id) { "gid://gitlab/VirtualRegistries::Packages::Maven::Registry/#{non_existing_record_id}" }

      it_behaves_like 'returns null for mavenVirtualRegistry'
    end
  end

  private

  def setup_default_configuration
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end
end
