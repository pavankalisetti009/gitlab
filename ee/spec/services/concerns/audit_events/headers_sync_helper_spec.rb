# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary for creating test records
RSpec.describe AuditEvents::HeadersSyncHelper, feature_category: :audit_events do
  let(:test_class) { Class.new { include AuditEvents::HeadersSyncHelper } }
  let(:helper) { test_class.new }

  describe '#sync_legacy_headers' do
    let_it_be(:group) { create(:group) }
    let_it_be(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Header-1' => { 'value' => 'value-1', 'active' => true },
            'Header-2' => { 'value' => 'value-2', 'active' => false }
          }
        })
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive(:http?).and_return(true)
    end

    it 'creates headers in legacy destination' do
      expect do
        helper.sync_legacy_headers(stream_destination, legacy_destination)
      end.to change { AuditEvents::Streaming::Header.count }.by(2)

      headers = legacy_destination.headers.order(:key)

      expect(headers.map(&:key)).to contain_exactly('Header-1', 'Header-2')
      expect(headers.map(&:value)).to contain_exactly('value-1', 'value-2')
      expect(headers.map(&:active)).to contain_exactly(true, false)
    end

    it 'removes existing headers before syncing' do
      create(:audit_events_streaming_header,
        key: 'Old-Header',
        external_audit_event_destination: legacy_destination
      )

      expect do
        helper.sync_legacy_headers(stream_destination, legacy_destination)
      end.to change { AuditEvents::Streaming::Header.count }.by(1)
      expect(legacy_destination.headers.pluck(:key)).not_to include('Old-Header')
    end

    context 'with instance level destination' do
      let_it_be(:instance_destination) { create(:instance_external_audit_event_destination) }
      let_it_be(:instance_stream_destination) do
        create(:audit_events_instance_external_streaming_destination, :http,
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Header-1' => { 'value' => 'value-1', 'active' => true }
            }
          })
      end

      before do
        instance_stream_destination.update_column(:legacy_destination_ref, instance_destination.id)
        allow(instance_stream_destination).to receive(:http?).and_return(true)
        allow(instance_destination).to receive(:instance_level?).and_return(true)
      end

      it 'creates instance headers' do
        expect do
          helper.sync_legacy_headers(instance_stream_destination, instance_destination)
        end.to change { AuditEvents::Streaming::InstanceHeader.count }.by(1)

        header = AuditEvents::Streaming::InstanceHeader.last
        expect(header.key).to eq('Header-1')
        expect(header.instance_external_audit_event_destination_id).to eq(instance_destination.id)
      end
    end

    context 'when error occurs' do
      let(:specific_exception) { StandardError.new('Test error') }

      before do
        allow(AuditEvents::Streaming::Header).to receive(:where).and_raise(specific_exception)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_legacy_headers(stream_destination, legacy_destination)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          specific_exception,
          audit_event_destination_model: stream_destination.class.name
        )
      end
    end
  end

  describe '#sync_header_to_streaming_destination' do
    let_it_be(:group) { create(:group) }
    let_it_be(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: { 'url' => 'http://example.com' })
    end

    let_it_be(:header) do
      create(:audit_events_streaming_header, key: 'Test-Header', value: 'test-value', active: true,
        external_audit_event_destination: legacy_destination)
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
      allow(stream_destination).to receive(:update).and_return(true)
    end

    it 'creates or updates header in streaming destination' do
      expect(stream_destination).to receive(:update) do |args|
        expect(args[:config]['headers']['Test-Header']).to eq({
          'value' => 'test-value',
          'active' => true
        })
        true
      end

      helper.sync_header_to_streaming_destination(legacy_destination, header)
    end

    context 'when streaming destination already has headers' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Existing-Header' => { 'value' => 'existing', 'active' => true }
            }
          }
        )
      end

      it 'adds new header to existing headers' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']).to include(
            'Existing-Header' => { 'value' => 'existing', 'active' => true },
            'Test-Header' => { 'value' => 'test-value', 'active' => true }
          )
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header)
      end
    end

    context 'when old key is provided and different from current key' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Old-Key' => { 'value' => 'old-value', 'active' => true }
            }
          }
        )
      end

      it 'removes old key and adds new key' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']).not_to include('Old-Key')
          expect(args[:config]['headers']['Test-Header']).to eq({
            'value' => 'test-value',
            'active' => true
          })
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header, 'Old-Key')
      end
    end

    context 'when old key is same as current key' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Test-Header' => { 'value' => 'old-value', 'active' => false }
            }
          }
        )
      end

      it 'does not remove the key, just updates it' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']['Test-Header']).to eq({
            'value' => 'test-value',
            'active' => true
          })
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header, 'Test-Header')
      end
    end

    context 'when error occurs' do
      before do
        allow(stream_destination).to receive(:update).and_raise(StandardError.new("Test error"))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_header_to_streaming_destination(legacy_destination, header)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name,
          header_id: header.id
        )
      end
    end
  end

  describe '#sync_header_deletion_to_streaming_destination' do
    let_it_be(:group) { create(:group) }
    let_it_be(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Header-To-Delete' => { 'value' => 'value', 'active' => true },
            'Other-Header' => { 'value' => 'other-value', 'active' => true }
          }
        })
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
      allow(stream_destination).to receive(:update).and_return(true)
    end

    it 'removes the specified header from config' do
      expect(stream_destination).to receive(:update) do |args|
        expect(args[:config]['headers']).not_to include('Header-To-Delete')
        expect(args[:config]['headers']).to include('Other-Header')
        true
      end

      helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Header-To-Delete')
    end

    context 'when header does not exist in config' do
      it 'does not update the destination' do
        expect(stream_destination).not_to receive(:update)

        helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Non-Existent-Header')
      end
    end

    context 'when error occurs' do
      before do
        allow(stream_destination).to receive(:update).and_raise(StandardError.new('Test error'))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Header-To-Delete')

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name,
          header_key: 'Header-To-Delete'
        )
      end
    end
  end

  describe 'header.destination' do
    let_it_be(:group) { create(:group) }

    context 'with regular header' do
      let!(:destination) { create(:external_audit_event_destination, group: group) }
      let!(:header) { create(:audit_events_streaming_header, external_audit_event_destination: destination) }

      it 'finds regular destination' do
        expect(header.destination).to eq(destination)
      end
    end

    context 'with instance header' do
      let!(:destination) { create(:instance_external_audit_event_destination) }
      let!(:header) do
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: destination)
      end

      it 'finds instance destination' do
        expect(header.destination).to eq(destination)
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
