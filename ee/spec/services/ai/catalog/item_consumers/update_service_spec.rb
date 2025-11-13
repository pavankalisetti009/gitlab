# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  it_behaves_like 'ItemConsumers::EventsTracking' do
    subject { described_class.new(build(:ai_catalog_item_consumer), build(:user), {}) }
  end

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer) }
    let_it_be(:project) { create(:project, group: group) }

    let(:params) { { pinned_version_prefix: '1.1' } }

    subject(:response) { described_class.new(item_consumer, user, params).execute }

    shared_examples 'Ai::Catalog::ItemConsumers::UpdateService' do
      context 'when user does not have permission' do
        let(:user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('You have insufficient permission to update this item consumer')
        end

        it 'does not track internal event on failure' do
          expect { response }.not_to trigger_internal_events('update_ai_catalog_item_consumer')
        end
      end

      context 'when user has permission' do
        let(:user) { maintainer }

        it 'returns success response' do
          expect(response).to be_success
        end

        it 'updates the item consumer' do
          expect { response }.to change { item_consumer.reload.pinned_version_prefix }.from(nil).to('1.1')
        end

        it 'tracks internal event on successful update' do
          expect { response }.to trigger_internal_events('update_ai_catalog_item_consumer').with(
            user: maintainer,
            project: item_consumer.project,
            namespace: item_consumer.group,
            additional_properties: {
              label: 'true',
              property: 'true'
            }
          ).and increment_usage_metrics('counts.count_total_update_ai_catalog_item_consumer')
        end

        context 'when the item consumer cannot be updated' do
          let(:params) { { pinned_version_prefix: 'a' * 51 } }

          it 'returns an error' do
            expect(response).to be_error
            expect(response.message).to contain_exactly('Pinned version prefix is too long (maximum is 50 characters)')
          end

          it 'does not track internal event on failure' do
            expect { response }.not_to trigger_internal_events('update_ai_catalog_item_consumer')
          end
        end
      end
    end

    context 'with a project level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }

      it_behaves_like 'Ai::Catalog::ItemConsumers::UpdateService'
    end

    context 'with a group level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, group: group) }

      it_behaves_like 'Ai::Catalog::ItemConsumers::UpdateService'
    end
  end
end
