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

    let(:pinned_version_prefix) { latest_released_version.version }
    let(:params) { { pinned_version_prefix: pinned_version_prefix } }

    subject(:response) { described_class.new(item_consumer, user, params).execute }

    shared_examples 'error' do |message:|
      it 'does not change the item consumer and returns the error message' do
        expect { response }.not_to change { item_consumer.reload.attributes }
        expect(response).to be_error
        expect(response.message).to contain_exactly(message)
      end

      it 'does not track internal event' do
        expect { response }.not_to trigger_internal_events('update_ai_catalog_item_consumer')
      end
    end

    shared_examples 'Ai::Catalog::ItemConsumers::UpdateService' do
      let_it_be(:older_released_version) do
        create(:ai_catalog_item_version, :released, item: item_consumer.item, version: '1.0.0', project: project)
      end

      let_it_be(:latest_released_version) do
        create(:ai_catalog_item_version, :released, item: item_consumer.item, version: '2.0.0', project: project)
      end

      let_it_be(:latest_draft_version) do
        create(:ai_catalog_item_version, :draft, item: item_consumer.item, version: '3.0.0', project: project)
      end

      context 'when user does not have permission' do
        let(:user) { developer }

        it_behaves_like 'error', message: 'You have insufficient permission to update this item consumer'
      end

      context 'when user has permission' do
        let(:user) { maintainer }

        it 'returns success response' do
          expect(response).to be_success
        end

        it 'updates the item consumer' do
          expect { response }
            .to change { item_consumer.reload.pinned_version_prefix }
            .to(latest_released_version.version)
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

        context 'when the pinned_version_prefix is not a full version' do
          let(:pinned_version_prefix) { '1.1' }

          it_behaves_like 'error', message: 'pinned_version_prefix is not a valid version string'
        end

        context 'when the pinned_version_prefix is of a draft version' do
          let(:pinned_version_prefix) { latest_draft_version.version }

          it_behaves_like 'error',
            message: 'pinned_version_prefix must resolve to the latest released version of the item'
        end

        context 'when the pinned_version_prefix is not of a version that exists' do
          let(:pinned_version_prefix) { '12.34.56' }

          it_behaves_like 'error',
            message: 'pinned_version_prefix must resolve to the latest released version of the item'
        end

        context 'when the pinned_version_prefix is not of the latest released version' do
          let(:pinned_version_prefix) { older_released_version.version }

          it_behaves_like 'error',
            message: 'pinned_version_prefix must resolve to the latest released version of the item'
        end

        context 'when the pinned_version_prefix is nil' do
          let(:pinned_version_prefix) { nil }

          it_behaves_like 'error', message: 'pinned_version_prefix is not a valid version string'
        end

        context 'when the pinned_version_prefix is not given' do
          let(:params) { super().except(:pinned_version_prefix) }

          it 'is successful, but a no-op' do
            # Note, will be a no-op until the service can update another attribute
            expect { response }.not_to change { item_consumer.reload.attributes }
            expect(response).to be_success
          end
        end

        context 'when the item consumer cannot be updated' do
          before do
            allow_next_instance_of(::Ai::Catalog::ItemConsumers::UpdateService) do |service|
              allow(service).to receive(:item_consumer).and_return(item_consumer)
            end

            allow(item_consumer).to receive(:update).and_return(false)
            item_consumer.errors.add(:base, 'Update failed')
          end

          it_behaves_like 'error', message: 'Update failed'
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
