# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Test uses a lot of helpers, and will be reviewed in https://gitlab.com/gitlab-org/gitlab/-/issues/495021
RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    subject(:available_services) { described_class.new.read_available_services }

    it 'parses service data from access_data.yml' do
      expect(available_services).to include({
        duo_chat: be_instance_of(CloudConnector::SelfSigned::AvailableServiceData)
      })
    end

    # NOTE: Duo Pro is internally still referred to as "code_suggestions", which can be confusing.
    it 'configures AvailableServiceData objects correctly' do
      expect(available_services[:duo_chat].name).to eq(:duo_chat)
      expect(available_services[:duo_chat].cut_off_date).to eq(Time.zone.parse("2024-10-17 00:00:00 UTC"))
      expect(available_services[:duo_chat].add_on_names).to match_array(%w[code_suggestions duo_enterprise])
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
