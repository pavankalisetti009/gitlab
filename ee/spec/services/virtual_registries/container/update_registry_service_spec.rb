# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Container::UpdateRegistryService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, group: group) }

  let(:available) { true }
  let(:params) do
    {
      name: 'New name',
      description: 'New description'
    }
  end

  describe '#execute' do
    subject(:result) { described_class.new(registry: registry, current_user: current_user, params: params).execute }

    before do
      allow(::VirtualRegistries::Container)
        .to receive(:virtual_registry_available?)
        .with(group, current_user)
        .and_return(available)
    end

    it 'updates a registry name and description successfully' do
      expect { result }
        .to change { registry.reload.name }.to('New name')
        .and change { registry.description }.to('New description')
    end

    it 'returns a success response with the registry' do
      expect(result.status).to eq(:success)
      expect(result.payload).to have_attributes(
        id: registry.id,
        name: 'New name',
        description: 'New description'
      )
    end

    context 'when virtual registry is not available' do
      let(:available) { false }

      it 'returns an error response' do
        expect(result.status).to eq(:error)
        expect(result.message).to include('Container virtual registry not available')
      end

      it 'does not update the registry name' do
        expect { result }.not_to change { registry.reload.name }
      end
    end

    context 'with invalid parameters' do
      let(:params) { { name: nil, description: 'New description' } }

      it 'fails to update a registry' do
        expect(result.status).to eq(:error)
      end

      it 'returns validation error messages' do
        expect(result.message).to include("Name can't be blank")
      end

      it 'does not update the registry name' do
        expect { result }.not_to change { registry.reload.name }
      end
    end

    context 'with unallowed parameters' do
      let(:params) { { name: 'New name', description: 'New description', group_id: non_existing_record_id } }

      it 'updates a registry name and description successfully' do
        expect { result }
          .to change { registry.reload.name }.to('New name')
          .and change { registry.description }.to('New description')
      end

      it 'returns a success response with the registry' do
        expect(result.status).to eq(:success)
        expect(result.payload).to have_attributes(
          id: registry.id,
          name: 'New name',
          description: 'New description'
        )
      end

      it 'does not update the registry group id' do
        expect { result }.not_to change { registry.reload.group_id }
      end
    end
  end
end
