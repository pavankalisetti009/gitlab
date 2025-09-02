# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::BaseStreamer, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'delete_issue' }
  let(:streamer) { described_class.new(event_type, audit_event) }

  describe '#initialize' do
    it 'sets audit operation and event' do
      expect(streamer.event_type).to eq(event_type)
      expect(streamer.audit_event).to eq(audit_event)
    end
  end

  describe '#streamable?' do
    it 'raises NotImplementedError' do
      expect { streamer.streamable? }.to raise_error(NotImplementedError)
    end
  end

  describe '#destinations' do
    it 'raises NotImplementedError' do
      expect { streamer.send(:destinations) }.to raise_error(NotImplementedError)
    end
  end

  describe '#execute' do
    let(:destination) { build(:external_audit_event_destination, group: create(:group)) }
    let(:test_streamer) do
      dest = destination
      Class.new(described_class) do
        def streamable?
          true
        end

        define_method(:destinations) { [dest] }
      end
    end

    subject(:execute) { test_streamer.new(event_type, audit_event).execute }

    context 'when not streamable' do
      let(:test_streamer) do
        Class.new(described_class) do
          def streamable?
            false
          end

          def destinations
            []
          end
        end
      end

      it 'does not stream to destinations' do
        expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)
        execute
      end
    end

    context 'when streamable' do
      before do
        allow(destination).to receive(:category).and_return('http')
      end

      context 'when destination is allowed to stream' do
        before do
          allow(destination).to receive(:allowed_to_stream?).and_return(true)
        end

        it 'streams to destinations' do
          expect_next_instance_of(AuditEvents::Streaming::Destinations::HttpStreamDestination) do |streamer|
            expect(streamer).to receive(:stream)
          end

          execute
        end
      end

      context 'when destination is not allowed to stream' do
        before do
          allow(destination).to receive(:allowed_to_stream?).and_return(false)
        end

        it 'does not stream to destinations' do
          expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)

          execute
        end
      end
    end
  end

  describe '#track_and_stream' do
    let(:destination) { build(:external_audit_event_destination, group: create(:group)) }

    before do
      allow(destination).to receive(:category).and_return('http')
    end

    it 'tracks exception when error occurs' do
      allow(streamer).to receive(:track_audit_event).and_raise(StandardError)

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

      streamer.send(:track_and_stream, destination)
    end
  end

  describe '#stream_to_destination' do
    let(:destination) { create(:external_audit_event_destination, group: create(:group)) }

    subject(:stream_to_destination) { streamer.send(:stream_to_destination, destination) }

    before do
      allow(destination).to receive(:category).and_return('http')
    end

    context 'when destination category is valid' do
      it 'streams to destination' do
        expect_next_instance_of(AuditEvents::Streaming::Destinations::HttpStreamDestination,
          event_type, audit_event, destination) do |stream_dest|
          expect(stream_dest).to receive(:stream)
        end

        stream_to_destination
      end
    end

    context 'when destination category is aws' do
      before do
        allow(destination).to receive(:category).and_return('aws')
      end

      it 'uses AmazonS3StreamDestination' do
        expect_next_instance_of(AuditEvents::Streaming::Destinations::AmazonS3StreamDestination,
          event_type, audit_event, destination) do |stream_dest|
          expect(stream_dest).to receive(:stream)
        end

        stream_to_destination
      end
    end

    context 'when destination category is gcp' do
      before do
        allow(destination).to receive(:category).and_return('gcp')
      end

      it 'uses GoogleCloudLoggingStreamDestination' do
        expect_next_instance_of(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination,
          event_type, audit_event, destination) do |stream_dest|
          expect(stream_dest).to receive(:stream)
        end

        stream_to_destination
      end
    end

    context 'when destination category is invalid' do
      before do
        allow(destination).to receive(:category).and_return('invalid')
      end

      it 'raises ArgumentError' do
        expect { stream_to_destination }.to raise_error(ArgumentError, 'Streamer class for category not found')
      end
    end
  end

  describe '#track_audit_event' do
    subject(:track_audit_event) { streamer.send(:track_audit_event) }

    using RSpec::Parameterized::TableSyntax

    context 'with different audit operations' do
      where(:operation, :internal) do
        'delete_epic'       | true
        'delete_issue'      | true
        'delete_merge_request' | true
        'delete_work_item'  | true
        'project_created'   | false
        'unknown_operation' | false
      end

      with_them do
        let(:event_type) { operation }

        it 'tracks internal events appropriately' do
          if internal
            expect(streamer).to receive(:track_internal_event)
              .with('trigger_audit_event', additional_properties: { label: operation })
          else
            expect(streamer).not_to receive(:track_internal_event)
          end

          track_audit_event
        end
      end
    end
  end
end
