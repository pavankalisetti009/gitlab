# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::LicenseProbe, feature_category: :cloud_connector do
  describe '#execute', :with_license do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    where(:exists?, :cloud, :expired, :trial, :success?, :message) do
      false | false | false  | false  | false | 'Contact GitLab customer support to obtain a license'
      true  | true  | true   | true   | true  | 'Subscription can be synchronized'
      true  | true  | true   | false  | true  | 'Subscription can be synchronized'
      true  | true  | false  | true   | true  | 'Subscription can be synchronized'
      true  | true  | false  | false  | true  | 'Subscription can be synchronized'
      true  | false | true   | true   | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | true   | false  | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | false  | true   | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | false  | false  | false | 'Contact GitLab customer support to upgrade your license'
    end

    with_them do
      let(:license) { build(:license, cloud: cloud, expired: expired, trial: trial) if exists? }

      it 'returns a correct result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to match(message)

        if exists?
          expect(result.details).to include(
            plan: license.plan,
            trial: license.trial?,
            expires_at: license.expires_at,
            grace_period_expired: license.grace_period_expired?,
            online_cloud_license: license.online_cloud_license?
          )
        else
          expect(result.details).to be_empty
        end
      end
    end
  end
end
