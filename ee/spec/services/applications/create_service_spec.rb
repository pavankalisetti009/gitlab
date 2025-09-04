# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Applications::CreateService, feature_category: :system_access do
  include TestRequestHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  let(:request) { test_request }
  let(:group) { create(:group) }
  let(:params) { attributes_for(:application, scopes: %w[read_user]) }

  subject(:service) { described_class.new(user, request, params) }

  describe '#audit_oauth_application_creation' do
    where(:case_name, :owner, :entity_type) do
      'instance application' | nil | 'User'
      'group application' | ref(:group) | 'Group'
      'user application' | ref(:user) | 'User'
    end

    with_them do
      before do
        stub_licensed_features(extended_audit_events: true)
        params[:owner] = owner
      end

      it 'creates audit event with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'oauth_application_created',
          author: user,
          scope: owner || user,
          target: instance_of(::Authn::OauthApplication),
          message: 'OAuth application added',
          additional_details: hash_including(
            application_name: anything,
            application_id: anything,
            scopes: %w[read_user]
          ),
          ip_address: request.remote_ip
        )

        service.execute
      end

      it 'creates AuditEvent with correct entity type' do
        expect { service.execute }.to change(AuditEvent, :count).by(1)
        expect(AuditEvent.last.entity_type).to eq(entity_type)
      end
    end

    context 'when application has multiple scopes' do
      let(:params) { attributes_for(:application, scopes: %w[api read_user read_repository]) }

      it 'includes all scopes in audit details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              scopes: %w[api read_user read_repository]
            )
          )
        )

        service.execute
      end
    end
  end

  context 'when executed from an internal api call' do
    before do
      stub_licensed_features(extended_audit_events: true)
    end

    context 'when request is nil' do
      let(:request) { nil }

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'skips audit event' do
        expect { service.execute }.not_to change { AuditEvent.count }
      end
    end

    context 'when request does not respond to #remote_ip' do
      before do
        allow(request).to receive(:respond_to?).and_call_original
        allow(request).to receive(:respond_to?).with(:remote_ip).and_return(false)
      end

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'skips audit event' do
        expect { service.execute }.not_to change { AuditEvent.count }
      end
    end

    context 'when application owner and user are both nil' do
      let(:user) { nil }
      let(:params) { attributes_for(:application, :without_owner, scopes: %w[read_user]) }

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'skips audit event' do
        expect { service.execute }.not_to change { AuditEvent.count }
      end
    end
  end

  context 'for ROPC' do
    where(:saas_feature_available, :feature_enabled, :ropc_enabled) do
      false | false | true
      false | true | true
      true | false | true
      true | true | false
    end

    with_them do
      before do
        stub_saas_features(disable_ropc_for_new_applications: saas_feature_available)
        stub_feature_flags(disable_ropc_for_new_applications: feature_enabled)
      end

      it 'sets ropc_enabled? correctly' do
        expect(service.execute.ropc_enabled?).to eq(ropc_enabled)
      end
    end
  end
end
