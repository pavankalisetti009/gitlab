# frozen_string_literal: true

FactoryBot.define do
  factory :instance_external_audit_event_destination, class: 'AuditEvents::InstanceExternalAuditEventDestination' do
    destination_url { FFaker::Internet.uri('https') }
    stream_destination_id { nil }
  end
end
