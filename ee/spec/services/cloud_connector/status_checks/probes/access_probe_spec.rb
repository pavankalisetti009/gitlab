# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::AccessProbe, :freeze_time, feature_category: :cloud_connector do
  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    let(:now) { Time.current }

    # nil trait means record is missing
    where(:access_trait, :token_trait, :success?, :message) do
      :current | :active  | true  | 'Access data is valid'
      nil      | :active  | false | 'Access data is missing'
      :stale   | :active  | false | 'Access data is stale'
      :current | nil      | false | 'Access token is missing'
      :current | :expired | false | 'Access token has expired'
    end

    with_them do
      it 'returns the expected result' do
        create(:cloud_connector_access, access_trait) if access_trait
        create(:service_access_token, token_trait) if token_trait

        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to eq(message)
      end
    end
  end
end
