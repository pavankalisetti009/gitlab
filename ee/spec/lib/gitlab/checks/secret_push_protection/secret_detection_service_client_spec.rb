# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient, feature_category: :secret_detection do
  include_context 'secrets check context'

  let(:audit_logger) { instance_double(Gitlab::Checks::SecretPushProtection::AuditLogger) }
  let(:client) { described_class.new(project: project) }
  let(:log_messages) { described_class::LOG_MESSAGES }

  let(:payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      id: new_blob_reference,
      data: "BASE_URL=https://foo.bar",
      offset: 1
    )
  end

  before do
    allow(::Gitlab::ErrorTracking).to receive(:track_exception)
  end

  describe '#use_secret_detection_service?' do
    before do
      stub_feature_flags(use_secret_detection_service: sds_ff_enabled)
      stub_saas_features(secret_detection_service: saas_feature_enabled)
      stub_application_setting(gitlab_dedicated_instance: dedicated_instance)
    end

    subject(:use_service) { client.use_secret_detection_service? }

    context 'when feature flag enabled, SaaS available, and not dedicated' do
      let(:sds_ff_enabled) { true }
      let(:saas_feature_enabled) { true }
      let(:dedicated_instance) { false }

      it { is_expected.to be(true) }
    end

    where(:desc, :sds_ff_enabled, :saas_feature_enabled, :dedicated_instance) do
      [
        ['feature flag disabled', false, true, false],
        ['instance is not SaaS', true, false, false],
        ['instance is dedicated', true, true, true]
      ]
    end

    with_them do
      it 'logs disabled message and returns false' do
        msg = format(
          log_messages[:sds_disabled],
          sds_ff_enabled: sds_ff_enabled,
          saas_feature_enabled: saas_feature_enabled,
          is_not_dedicated: !dedicated_instance
        )

        expect(client.use_secret_detection_service?).to be false
        expect(logged_messages[:info]).to include(
          hash_including("message" => msg, "class" => described_class.name)
        )
      end
    end
  end

  describe '#send_request_to_sds' do
    let(:grpc_client) { instance_double(::Gitlab::SecretDetection::GRPC::Client) }
    let!(:exclusion) do
      create(:project_security_exclusion, :active, :with_path, project: project, value: 'file-exclusion-1.rb')
    end

    before do
      allow(client).to receive(:setup_sds_client)
      allow(client).to receive_messages(sds_client: grpc_client, sds_auth_token: 'token123')
    end

    it 'invokes run_scan with request and token' do
      expect(grpc_client).to receive(:run_scan).with(
        request: kind_of(::Gitlab::SecretDetection::GRPC::ScanRequest),
        auth_token: 'token123'
      )
      client.send_request_to_sds([payload], exclusions: { path: [exclusion] })
    end

    it 'rescues and tracks on error' do
      allow(grpc_client).to receive(:run_scan).and_raise(StandardError)
      expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(StandardError))
      expect { client.send_request_to_sds([payload]) }.not_to raise_error
    end

    it 'does nothing if sds_client is nil' do
      allow(client).to receive(:setup_sds_client)
      allow(client).to receive(:sds_client).and_return(nil)

      allow(grpc_client).to receive(:run_scan)

      expect { client.send_request_to_sds([payload]) }.not_to raise_error
      expect(grpc_client).not_to have_received(:run_scan)
    end
  end
end
