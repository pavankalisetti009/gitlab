# frozen_string_literal: true

RSpec.shared_examples 'creates a streaming destination' do |legacy_model_class, attributes_proc|
  before do
    stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)
  end

  let(:attributes) { instance_exec(&attributes_proc) }
  it 'creates a streaming destination with correct attributes' do
    expect { mutate }
    .to change { legacy_model_class.count }.by(1)

    legacy_destination = legacy_model_class.last
    stream_destination = legacy_destination.stream_destination

    aggregate_failures do
      expect(stream_destination.legacy_destination_ref).to eq(legacy_destination.id)
      expect(legacy_destination.stream_destination_id).to eq(stream_destination.id)

      attributes[:streaming].each do |key, value|
        expect(stream_destination.config[key]).to eq(value)
      end
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)
    end

    it 'does not create a streaming destination' do
      expect { mutate }
        .to not_change(AuditEvents::Group::ExternalStreamingDestination, :count)
        .and not_change(AuditEvents::Instance::ExternalStreamingDestination, :count)
    end
  end
end
