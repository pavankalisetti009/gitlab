# frozen_string_literal: true

RSpec.shared_examples 'creates a legacy destination' do |model_class, attributes_proc|
  let(:attributes_map) { instance_exec(&attributes_proc) }

  before do
    stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)
  end

  def get_secret_token(model, category)
    case category
    when :http then model.verification_token
    when :aws then model.secret_access_key
    when :gcp then model.private_key
    end
  end

  it 'creates a legacy destination with correct attributes' do
    expect { mutate }.to change { model_class.count }.by(1)

    source_model = model_class.last
    expect(source_model).to be_present

    stream_model = source_model
    legacy_model = source_model.legacy_destination

    expect(legacy_model).to be_present

    expect(stream_model.config).to include(attributes_map[:streaming])
    attributes_map[:legacy].each do |attr, value|
      expect(legacy_model.public_send(attr)).to eq(value)
    end
    expect(get_secret_token(legacy_model, stream_model.category.to_sym)).to eq(source_model.secret_token)
    expect(legacy_model.namespace_id).to eq(stream_model.group_id) if stream_model.respond_to?(:group_id)

    if stream_model.http?
      expect(legacy_model.event_type_filters.count).to eq(stream_model.event_type_filters.count)
      expect(legacy_model.namespace_filter&.namespace).to eq(stream_model.namespace_filters.first&.namespace)
    end

    expect(stream_model.name).to eq(legacy_model.name)
    expect(stream_model.legacy_destination_ref).to eq(legacy_model.id)
    expect(legacy_model.stream_destination_id).to eq(stream_model.id)
  end
end
