# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::DestroyService, feature_category: :workflow_catalog do
  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:response) { described_class.new(item_consumer, current_user).execute }

    context 'with a project level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('You have insufficient permissions to delete this item consumer')
        end
      end

      context 'when user has permission' do
        let(:current_user) { maintainer }

        it 'deletes the item consumer' do
          expect(response).to be_success
          expect { Ai::Catalog::ItemConsumer.find(item_consumer.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'with a group level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, group: group) }

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('You have insufficient permissions to delete this item consumer')
        end
      end

      context 'when user has permission' do
        let(:current_user) { maintainer }

        it 'deletes the item consumer' do
          expect(response).to be_success
          expect { Ai::Catalog::ItemConsumer.find(item_consumer.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
