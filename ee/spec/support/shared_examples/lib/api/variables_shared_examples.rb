# frozen_string_literal: true

RSpec.shared_examples 'audit event for variable access' do |variable_type|
  let(:audited_variable) { create(variable_type, **variable_attributes) }

  before do
    stub_licensed_features(audit_events: true)
  end

  context 'when variable is not hidden' do
    let(:is_hidden_variable) { false }
    let(:is_masked_variable) { false }

    it 'creates an audit event' do
      expect do
        make_request
      end.to change { AuditEvent.count }.by(1)

      audit_event = AuditEvent.order(:id).last
      expect(audit_event.details[:custom_message]).to eq(
        "CI/CD variable '#{audited_variable.key}' accessed with the API"
      )
      expect(audit_event.details[:event_name]).to eq('variable_viewed_api')
      expect(audit_event.details[:target_details]).to eq(audited_variable.key)
      expect(audit_event.author_id).to eq(user.id)
      expect(audit_event.entity_id).to eq(expected_entity_id)
    end
  end

  context 'when variable is hidden' do
    let(:is_hidden_variable) { true }
    let(:is_masked_variable) { true }

    it 'creates an audit event with mention to hidden variable' do
      expect do
        make_request
      end.to change { AuditEvent.count }.by(1)

      audit_event = AuditEvent.order(:id).last
      expect(audit_event.details[:custom_message]).to eq(
        "CI/CD variable '#{audited_variable.key}' accessed with the API (hidden variable, no value shown)"
      )
      expect(audit_event.details[:event_name]).to eq('variable_viewed_api')
      expect(audit_event.details[:target_details]).to eq(audited_variable.key)
      expect(audit_event.author_id).to eq(user.id)
      expect(audit_event.entity_id).to eq(expected_entity_id)
    end
  end
end
