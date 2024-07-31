# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CloudConnector, feature_category: :cloud_connector do
  describe '.gitlab_realm' do
    subject { described_class.gitlab_realm }

    context 'when the current instance is gitlab.com', :saas do
      it { is_expected.to eq(described_class::GITLAB_REALM_SAAS) }
    end

    context 'when the current instance is not saas' do
      it { is_expected.to eq(described_class::GITLAB_REALM_SELF_MANAGED) }
    end
  end

  describe '.headers' do
    let(:expected_duo_seat_count) { 0 }

    let(:expected_headers) do
      {
        'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
        'X-Gitlab-Instance-Id' => an_instance_of(String),
        'X-Gitlab-Realm' => Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'X-Gitlab-Version' => Gitlab.version_info.to_s,
        'X-Gitlab-Duo-Seat-Count' => expected_duo_seat_count.to_s
      }
    end

    subject(:headers) { described_class.headers(user) }

    context 'when the the user is present' do
      let(:user) { build(:user, id: 1) }

      it 'generates a hash with the required fields based on the user' do
        expect(headers).to match(expected_headers.merge('X-Gitlab-Global-User-Id' => an_instance_of(String)))
      end
    end

    context 'when the the user argument is nil' do
      let(:user) { nil }

      it 'generates a hash without `X-Gitlab-Global-User-Id`' do
        expect(headers).to match(expected_headers)
      end
    end

    describe 'duo seat count' do
      let(:user) { nil }
      let(:expected_duo_seat_count) { 10 }

      it 'returns the number of duo seats purchased' do
        expect(GitlabSubscriptions::AddOnPurchase).to receive(:maximum_duo_seat_count).and_return(
          expected_duo_seat_count
        )

        expect(headers).to match(expected_headers)
      end
    end
  end
end
