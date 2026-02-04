# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::EventPublicationService, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary_node) { create(:geo_node, :primary) }
  let_it_be(:secondary_node) { create(:geo_node) }

  let(:replicable_name) { 'project_repository' }
  let(:event_name) { :created }
  let(:payload) { { project_id: 123, repository_storage: 'default' } }
  let(:service) { described_class.new(replicable_name: replicable_name, event_name: event_name, payload: payload) }

  describe '#execute' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'when on a primary site with secondary nodes' do
      context 'when event creation succeeds' do
        it 'creates a Geo::Event with correct attributes' do
          expect(Geo::Event).to receive(:create!).with(
            replicable_name: replicable_name,
            event_name: event_name,
            payload: payload
          )

          service.execute
        end

        it 'returns a successful ServiceResponse' do
          result = service.execute

          expect(result).to be_success
          expect(result.message).to eq('::Geo::Event was successfully created.')
          expect(result.payload).to include(replicable_name: replicable_name, event_name: event_name, payload: payload)
        end

        it 'increase the Geo::Event count by 1' do
          expect { service.execute }.to change { ::Geo::Event.count }.from(0).to(1)
        end

        it 'increase the Geo::EventLog count by 1' do
          expect { service.execute }.to change { ::Geo::EventLog.count }.from(0).to(1)
        end
      end

      context 'when event creation fails with ActiveRecord::RecordInvalid' do
        let(:error) { ActiveRecord::RecordInvalid.new }

        before do
          allow(Geo::Event).to receive(:create!).and_raise(error)
        end

        it 'logs the error' do
          expect(service).to receive(:log_error).with(
            '::Geo::Event could not be created.',
            error,
            { replicable_name: replicable_name, event_name: event_name, payload: payload }
          )

          service.execute
        end

        it 'returns an error ServiceResponse' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('::Geo::Event could not be created.')
          expect(result.payload).to include(replicable_name: replicable_name, event_name: event_name, payload: payload)
        end
      end

      context 'when event creation fails with NoMethodError' do
        let(:error) { NoMethodError.new }

        before do
          allow(Geo::Event).to receive(:create!).and_raise(error)
        end

        it 'logs the error' do
          expect(service).to receive(:log_error).with(
            '::Geo::Event could not be created.',
            error,
            { replicable_name: replicable_name, event_name: event_name, payload: payload }
          )

          service.execute
        end

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('::Geo::Event could not be created.')
        end
      end
    end

    context 'when not on a primary site' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('::Geo::Event cannot be created on Geo Secondary sites')
        expect(result.payload).to include(replicable_name: replicable_name, event_name: event_name, payload: payload)
      end

      it 'does not create events' do
        expect(Geo::Event).not_to receive(:create!)
        expect(Geo::EventLog).not_to receive(:create!)

        service.execute
      end

      it 'does not increase the event log counts' do
        expect { service.execute }.not_to change { ::Geo::EventLog.count }
      end

      it 'does not increase the event count' do
        expect { service.execute }.not_to change { ::Geo::Event.count }
      end
    end

    context 'when on primary but no secondary nodes exist' do
      before do
        stub_current_geo_node(primary_node)
        allow(Gitlab::Geo).to receive(:secondary_nodes).and_return([])
      end

      it 'returns an error without creating events' do
        expect(Geo::Event).not_to receive(:create!)
        expect(Geo::EventLog).not_to receive(:create!)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('::Geo::Event cannot be sent: there are no secondary sites')
      end
    end
  end
end
