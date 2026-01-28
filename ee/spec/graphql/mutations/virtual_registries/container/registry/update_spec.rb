# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Registry::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:virtual_registry) { create(:virtual_registries_container_registry, group: group) }

  let(:params) do
    {
      name: 'New name',
      description: 'New description'
    }
  end

  let(:expected_attributes) do
    {
      name: 'New name',
      description: 'New description'
    }
  end

  let(:mutation_params) do
    {
      id: id,
      name: 'New name',
      description: 'New description'
    }
  end

  let(:id) do
    ::Gitlab::GlobalId.as_global_id(virtual_registry.id, model_name: 'VirtualRegistries::Container::Registry')
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }
  let(:registry) { subject[:registry] }

  specify { expect(described_class).to require_graphql_authorizations(:update_virtual_registry) }

  describe '#resolve' do
    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(container_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    def resolve
      mutation.resolve(**mutation_params)
    end

    subject(:resolver) { resolve }

    shared_examples 'raises resource not available error' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user does not have permission to update a virtual registry' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permissions to update a virtual registry' do
      before_all do
        group.add_owner(current_user)
      end

      it 'updates a registry' do
        expect(registry).to have_attributes(expected_attributes)
      end

      context 'when record is not valid' do
        let(:mutation_params) do
          {
            id: id,
            name: nil,
            description: 'Description'
          }
        end

        it 'returns errors' do
          expect(resolver[:errors]).to include("Name can't be blank")
          expect(registry).to be_nil
        end
      end

      context 'when the virtual registries setting enabled is false' do
        before do
          allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
            :virtual_registries_setting, :disabled, group: group))
        end

        it_behaves_like 'raises resource not available error'
      end
    end

    context 'with container_virtual_registries feature flag turned off' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'raises resource not available error'
    end
  end
end
