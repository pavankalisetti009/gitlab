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
    context 'when SaaS feature is available' do
      before do
        stub_saas_features(disable_ropc_for_new_applications: true)
      end

      it 'sets ropc_enabled to false' do
        expect(service.execute.ropc_enabled?).to be_falsy
      end
    end

    context 'when SaaS feature is not available' do
      before do
        stub_saas_features(disable_ropc_for_new_applications: false)
      end

      it 'sets ropc_enabled to true' do
        expect(service.execute.ropc_enabled?).to be_truthy
      end
    end
  end

  describe '.disable_ropc_for_all_applications?' do
    subject { described_class.disable_ropc_for_all_applications? }

    context 'when disable_ropc_for_all_applications SaaS feature is enabled' do
      before do
        stub_saas_features(disable_ropc_for_all_applications: true)
      end

      it { is_expected.to be true }
    end

    context 'when disable_ropc_for_all_applications SaaS feature is disabled' do
      before do
        stub_saas_features(disable_ropc_for_all_applications: false)
      end

      it { is_expected.to be false }
    end
  end
end
