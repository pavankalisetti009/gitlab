# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::LegacyDestinationSyncHelper, feature_category: :audit_events do
  let(:helper) { Class.new { include AuditEvents::LegacyDestinationSyncHelper }.new }

  describe '#create_stream_destination' do
    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)
      end

      describe 'http destinations' do
        context 'when instance level' do
          let!(:header) do
            create(:instance_audit_events_streaming_header, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              key: 'Custom-Header',
              value: 'test-value',
              active: true)
          end

          let!(:source) do
            create(:instance_external_audit_event_destination, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook',
              headers: [header])
          end

          let!(:event_type_filter) do
            create(:audit_events_streaming_instance_event_type_filter, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              instance_external_audit_event_destination: source,
              audit_event_type: 'user_created')
          end

          let!(:namespace_filter) do
            create(:audit_events_streaming_http_instance_namespace_filter, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              instance_external_audit_event_destination: source)
          end

          it 'creates streaming destination with all associated records' do
            destination = create_stream_destination(legacy_destination_model: source, category: :http,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('http')
              expect(destination.config['url']).to eq(source.destination_url)
              expect(destination.config['headers']).to include(
                'X-Gitlab-Event-Streaming-Token' => {
                  'value' => source.verification_token,
                  'active' => true
                },
                'Custom-Header' => {
                  'value' => 'test-value',
                  'active' => true
                }
              )
              expect(destination.secret_token).to eq(source.verification_token)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)

              expect(destination.event_type_filters.count).to eq(1)
              expect(destination.event_type_filters.first.audit_event_type).to eq('user_created')

              expect(destination.namespace_filters.count).to eq(1)
              expect(destination.namespace_filters.first.namespace)
                .to eq(namespace_filter.namespace)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests

          let!(:header) do
            create(:audit_events_streaming_header, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              key: 'Custom-Header',
              value: 'test-value',
              active: true)
          end

          let!(:source) do
            create(:external_audit_event_destination, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              group: group,
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook',
              headers: [header])
          end

          let!(:event_type_filter) do
            create(:audit_events_streaming_event_type_filter, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              external_audit_event_destination: source,
              audit_event_type: 'user_created')
          end

          let!(:namespace_filter) do
            create(:audit_events_streaming_http_namespace_filter, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              external_audit_event_destination: source,
              namespace: group)
          end

          it 'creates streaming destination with all associated records' do
            destination = create_stream_destination(legacy_destination_model: source, category: :http,
              is_instance: false)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('http')
              expect(destination.group).to eq(group)
              expect(destination.config['url']).to eq(source.destination_url)
              expect(destination.config['headers']).to include(
                'X-Gitlab-Event-Streaming-Token' => {
                  'value' => source.verification_token,
                  'active' => true
                },
                'Custom-Header' => {
                  'value' => 'test-value',
                  'active' => true
                }
              )
              expect(destination.secret_token).to eq(source.verification_token)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)

              expect(destination.event_type_filters.count).to eq(1)
              expect(destination.event_type_filters.first.audit_event_type).to eq('user_created')
              expect(destination.event_type_filters.first.namespace).to eq(group)

              expect(destination.namespace_filters.count).to eq(1)
              expect(destination.namespace_filters.first.namespace).to eq(group)
            end
          end
        end
      end

      describe 'aws destinations' do
        context 'when instance level' do
          let!(:source) do
            create(:instance_amazon_s3_configuration, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              access_key_xid: SecureRandom.hex(8),
              secret_access_key: 'test-secret-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :aws,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('aws')
              expect(destination.config['bucketName']).to eq(source.bucket_name)
              expect(destination.config['awsRegion']).to eq(source.aws_region)
              expect(destination.config['accessKeyXid']).to eq(source.access_key_xid)
              expect(destination.secret_token).to eq(source.secret_access_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests

          let!(:source) do
            create(:amazon_s3_configuration, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              group: group,
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              access_key_xid: SecureRandom.hex(8),
              secret_access_key: 'test-secret-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :aws,
              is_instance: false)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('aws')
              expect(destination.group).to eq(group)
              expect(destination.config['bucketName']).to eq(source.bucket_name)
              expect(destination.config['awsRegion']).to eq(source.aws_region)
              expect(destination.config['accessKeyXid']).to eq(source.access_key_xid)
              expect(destination.secret_token).to eq(source.secret_access_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end
      end

      describe 'gcp destinations' do
        context 'when instance level' do
          let!(:source) do
            create(:instance_google_cloud_logging_configuration, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :gcp,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('gcp')
              expect(destination.config['googleProjectIdName']).to eq(source.google_project_id_name)
              expect(destination.config['logIdName']).to eq(source.log_id_name)
              expect(destination.config['clientEmail']).to eq(source.client_email)
              expect(destination.secret_token).to eq(source.private_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests

          let!(:source) do
            create(:google_cloud_logging_configuration, # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
              name: 'test-destination',
              group: group,
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :gcp,
              is_instance: false)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('gcp')
              expect(destination.group).to eq(group)
              expect(destination.config['googleProjectIdName']).to eq(source.google_project_id_name)
              expect(destination.config['logIdName']).to eq(source.log_id_name)
              expect(destination.config['clientEmail']).to eq(source.client_email)
              expect(destination.secret_token).to eq(source.private_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end
      end

      context 'when an error occurs during creation' do
        let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
        let(:source) { create(:external_audit_event_destination, group: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
        let(:mock_destination) { build(:audit_events_group_external_streaming_destination, group: group) }

        before do
          allow(AuditEvents::Group::ExternalStreamingDestination)
            .to receive(:new)
            .and_return(mock_destination)

          allow(mock_destination)
            .to receive(:save!)
            .and_raise(described_class::CreateError, 'Test error')
        end

        it 'returns nil and tracks the error' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(
              an_instance_of(described_class::CreateError),
              audit_event_destination_model: source.class.name
            )

          expect(helper.create_stream_destination(legacy_destination_model: source, category: :http,
            is_instance: false)).to be_nil
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)
      end

      let!(:source) do
        create(:instance_external_audit_event_destination) # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need to persist for tests
      end

      it 'returns nil' do
        expect(helper.create_stream_destination(legacy_destination_model: nil, category: :http,
          is_instance: false)).to be_nil
      end
    end
  end
end
