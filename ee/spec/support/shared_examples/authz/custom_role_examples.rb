# frozen_string_literal: true

RSpec.shared_examples 'permission is allowed/disallowed with feature enabled' do
  with_them do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(license => true)
      end

      it { is_expected.to be_disallowed(permission) }

      context 'when admin mode enabled', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(permission) }
      end

      context 'when admin mode disabled' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(permission) }
      end
    end

    context 'when feature is disabled' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(license => false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_disallowed(permission) }
      end
    end
  end
end

RSpec.shared_examples 'custom role create service returns error' do
  it 'is not successful' do
    expect(create_role).to be_error
  end

  it 'returns the correct error messages' do
    expect(create_role.message).to include(error_message)
  end

  it 'does not create the role' do
    expect { create_role }.not_to change { role_klass.count }
  end

  it 'does not log an audit event' do
    expect { create_role }.not_to change { AuditEvent.count }
  end
end

RSpec.shared_examples 'custom role creation' do |audit_event_type, audit_event_message|
  context 'with valid params' do
    it 'is successful' do
      expect(create_role).to be_success
    end

    it 'returns the object with assigned attributes' do
      expect(create_role.payload[:member_role].name).to eq(role_name)
    end

    it 'creates the role correctly' do
      expect { create_role }.to change { role_klass.count }.by(1)

      role = role_klass.last
      expect(role.name).to eq(role_name)
      expect(role.permissions.select { |_k, v| v }.symbolize_keys).to eq(abilities)
    end

    include_examples 'audit event logging' do
      let(:licensed_features_to_stub) { { custom_roles: true } }
      let(:operation) { create_role.payload[:member_role] }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: audit_entity_id,
          entity_type: audit_entity_type,
          details: {
            author_name: user.name,
            event_name: audit_event_type,
            target_id: operation.id,
            target_type: operation.class.name,
            target_details: {
              name: operation.name,
              description: operation.description,
              abilities: abilities.keys.join(', ')
            }.to_s,
            custom_message: audit_event_message,
            author_class: user.class.name
          }
        }
      end
    end
  end
end
