# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::AccessProbe, :freeze_time, feature_category: :cloud_connector do
  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    let(:now) { Time.current }

    # nil trait means record is missing
    where(:access_trait, :token_trait, :success?, :message) do
      :current | :active  | true  | 'Subscription synchronized successfully'
      nil      | :active  | false | 'Subscription has not yet been synchronized'
      :stale   | :active  | false | 'Subscription has not been synchronized recently'
      :current | nil      | false | 'Access credentials not found'
      :current | :expired | false | 'Access credentials expired'
    end

    with_them do
      it 'returns the expected result' do
        create(:cloud_connector_access, access_trait) if access_trait
        create(:service_access_token, token_trait) if token_trait

        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to match(message)
      end
    end
  end
end
