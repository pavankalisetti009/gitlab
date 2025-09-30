# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::Security::PartnerTokenService, feature_category: :secret_detection do
  subject(:service) { described_class.new }

  let_it_be(:project) { create(:project) }

  def expect_token_status_to_match(token_status, status)
    expect(token_status).to have_attributes(
      security_finding_id: security_finding.id,
      project_id: security_finding.project.id,
      status: status,
      last_verified_at: Time.zone.now
    )
  end

  describe '#save_result', :freeze_time do
    let_it_be(:security_finding) { create(:security_finding, :with_finding_data) }
    let(:verified_at) { Time.zone.now }
    let(:result) do
      instance_double(Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus,
        status: :active,
        metadata: { verified_at: verified_at })
    end

    it 'creates token status record' do
      expect { service.save_result(security_finding, result) }
        .to change { Security::FindingTokenStatus.count }.by(1)

      token_status = Security::FindingTokenStatus.find_by(security_finding_id: security_finding.id)
      expect_token_status_to_match(token_status, 'active')
    end

    context 'when token status already exists' do
      let!(:existing_status) do
        create(:security_finding_token_status,
          security_finding: security_finding,
          status: :unknown,
          last_verified_at: 1.day.ago)
      end

      it 'updates existing record' do
        expect { service.save_result(security_finding, result) }
          .not_to change { Security::FindingTokenStatus.count }

        existing_status.reload
        expect_token_status_to_match(existing_status, 'active')
      end
    end

    context 'when save fails' do
      before do
        allow(Security::FindingTokenStatus).to receive(:upsert)
          .and_raise(ActiveRecord::RecordInvalid.new(Security::FindingTokenStatus.new))
      end

      it 'allows the error to bubble up' do
        expect { service.save_result(security_finding, result) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
