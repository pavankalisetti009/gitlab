# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillExternalInstanceAuditEventDestinationsFixed,
  feature_category: :audit_events do
  let(:connection) { ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_instance_external_audit_event_destinations) }
  let(:streaming_table) { table(:audit_events_instance_external_streaming_destinations) }
  let(:event_type_filters_table) { table(:audit_events_streaming_instance_event_type_filters) }
  let(:instance_event_type_filters_table) { table(:audit_events_instance_streaming_event_type_filters) }
  let(:namespace_filters_table) { table(:audit_events_streaming_http_instance_namespace_filters) }
  let(:instance_namespace_filters_table) { table(:audit_events_streaming_instance_namespace_filters) }
  let(:headers_table) { table(:instance_audit_events_streaming_headers) }
  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }

  let!(:root_group) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-org',
      path: 'gitlab-org',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:subgroup) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-subgroup',
      path: 'gitlab-subgroup',
      type: 'Group',
      parent_id: root_group.id
    ).tap { |namespace| namespace.update!(traversal_ids: [root_group.id, namespace.id]) }
  end

  let!(:simple_destination) do
    legacy_table.create!(
      name: "Simple HTTP Instance Destination",
      destination_url: "https://example.com/simple",
      encrypted_verification_token: 'dummy-encrypted-token',
      encrypted_verification_token_iv: 'dummy-iv',
      stream_destination_id: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:complex_destination) do
    legacy_table.create!(
      name: "Complex Instance Destination",
      destination_url: "https://example.com/complex",
      encrypted_verification_token: 'dummy-encrypted-token',
      encrypted_verification_token_iv: 'dummy-iv',
      stream_destination_id: nil,
      created_at: 2.days.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:migrated_destination) do
    destination = legacy_table.create!(
      name: "Already Migrated Instance Destination",
      destination_url: "https://example.com/migrated",
      encrypted_verification_token: 'dummy-encrypted-token',
      encrypted_verification_token_iv: 'dummy-iv',
      created_at: 4.days.ago,
      updated_at: 3.days.ago
    )

    streaming_dest = streaming_table.create!(
      name: destination.name,
      category: 0,
      config: {
        'url' => destination.destination_url,
        'headers' => {
          'X-Gitlab-Event-Streaming-Token' => {
            'value' => 'test-token',
            'active' => true
          }
        }
      },
      encrypted_secret_token: 'dummy-encrypted-token',
      encrypted_secret_token_iv: 'dummy-iv',
      legacy_destination_ref: destination.id,
      created_at: destination.created_at,
      updated_at: destination.updated_at
    )

    destination.update!(stream_destination_id: streaming_dest.id)
    destination
  end

  let!(:event_type_filters) do
    %w[user_created group_created project_created].map do |event_type|
      event_type_filters_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        audit_event_type: event_type,
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )
    end
  end

  let!(:namespace_filter) do
    namespace_filters_table.create!(
      audit_events_instance_external_audit_event_destination_id: complex_destination.id,
      namespace_id: subgroup.id,
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:headers) do
    [
      { key: 'X-Custom-Header-1', value: 'custom-value-1', active: true },
      { key: 'X-Custom-Header-2', value: 'custom-value-2', active: false }
    ].map do |header_data|
      headers_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        key: header_data[:key],
        value: header_data[:value],
        active: header_data[:active],
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )
    end
  end

  let(:migration) do
    described_class.new(
      start_id: [simple_destination.id, complex_destination.id, migrated_destination.id].min,
      end_id: [simple_destination.id, complex_destination.id, migrated_destination.id].max,
      batch_table: :audit_events_instance_external_audit_event_destinations,
      batch_column: :id,
      sub_batch_size: 5,
      pause_ms: 0,
      connection: connection
    )
  end

  describe '#perform' do
    before do
      model_class_double = class_double(AuditEvents::InstanceExternalAuditEventDestination)

      [simple_destination, complex_destination, migrated_destination].each do |dest|
        model_instance = instance_double(AuditEvents::InstanceExternalAuditEventDestination)
        allow(model_instance).to receive(:verification_token).and_return('test-token')
        allow(model_class_double).to receive(:find_by).with(id: dest.id).and_return(model_instance)
      end

      stub_const('::AuditEvents::InstanceExternalAuditEventDestination', model_class_double)
    end

    it 'creates streaming destinations for unmigrated records and updates them' do
      expect { migration.perform }.to change { streaming_table.count }.by(2)

      simple_destination.reload
      complex_destination.reload
      migrated_destination.reload

      expect(simple_destination.stream_destination_id).not_to be_nil
      expect(complex_destination.stream_destination_id).not_to be_nil
      expect(migrated_destination.stream_destination_id).not_to be_nil

      expect(migrated_destination.stream_destination_id).to eq(
        streaming_table.find_by(legacy_destination_ref: migrated_destination.id).id
      )
    end

    it 'properly migrates a simple destination without filters or headers' do
      migration.perform

      simple_destination.reload
      new_streaming_dest = streaming_table.find_by(legacy_destination_ref: simple_destination.id)

      expect(new_streaming_dest.name).to eq(simple_destination.name)
      expect(new_streaming_dest.category).to eq(0)

      config = new_streaming_dest.config

      expect(config['url']).to eq(simple_destination.destination_url)
      expect(instance_event_type_filters_table.where(external_streaming_destination_id: new_streaming_dest.id).count)
        .to eq(0)
      expect(instance_namespace_filters_table.where(external_streaming_destination_id: new_streaming_dest.id).count)
        .to eq(0)
    end

    it 'properly migrates a complex destination with filters and headers' do
      migration.perform

      complex_destination.reload
      new_streaming_dest = streaming_table.find_by(legacy_destination_ref: complex_destination.id)

      expect(new_streaming_dest.name).to eq(complex_destination.name)
      expect(new_streaming_dest.category).to eq(0)

      config = new_streaming_dest.config
      expect(config['url']).to eq(complex_destination.destination_url)
      expect(config['headers']['X-Custom-Header-1']['value']).to eq('custom-value-1')
      expect(config['headers']['X-Custom-Header-1']['active']).to be(true)
      expect(config['headers']['X-Custom-Header-2']['value']).to eq('custom-value-2')
      expect(config['headers']['X-Custom-Header-2']['active']).to be(false)

      migrated_filters = instance_event_type_filters_table
        .where(external_streaming_destination_id: new_streaming_dest.id)
      expect(migrated_filters.count).to eq(3)
      expect(migrated_filters.pluck(:audit_event_type)).to match_array(%w[user_created group_created project_created])

      migrated_namespace_filter = instance_namespace_filters_table
        .where(external_streaming_destination_id: new_streaming_dest.id)
      expect(migrated_namespace_filter.count).to eq(1)
      expect(migrated_namespace_filter.first.namespace_id).to eq(subgroup.id)
    end

    context 'with large number of records' do
      let!(:additional_destinations) do
        (1..5).map do |i|
          legacy_table.create!(
            name: "Batch Instance Destination #{i}",
            destination_url: "https://example.com/batch-#{i}",
            encrypted_verification_token: 'dummy-encrypted-token',
            encrypted_verification_token_iv: 'dummy-iv',
            stream_destination_id: nil,
            created_at: 5.days.ago,
            updated_at: 4.days.ago
          )
        end
      end

      let(:migration) do
        described_class.new(
          start_id: ([simple_destination.id, complex_destination.id,
            migrated_destination.id] + additional_destinations.map(&:id)).min,
          end_id: ([simple_destination.id, complex_destination.id,
            migrated_destination.id] + additional_destinations.map(&:id)).max,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'processes the records in batches' do
        model_class = ::AuditEvents::InstanceExternalAuditEventDestination
        additional_destinations.each do |dest|
          model_instance = instance_double(AuditEvents::InstanceExternalAuditEventDestination)
          allow(model_instance).to receive(:verification_token).and_return('test-token')
          allow(model_class).to receive(:find_by).with(id: dest.id).and_return(model_instance)
        end

        expect { migration.perform }.to change { streaming_table.count }.by(7)

        (additional_destinations + [simple_destination, complex_destination]).each do |destination|
          expect(destination.reload.stream_destination_id).not_to be_nil
        end
      end
    end
  end
end
