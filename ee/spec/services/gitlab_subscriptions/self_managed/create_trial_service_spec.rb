# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::CreateTrialService, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      email_address: 'john@example.com',
      company_name: 'ACME Corp',
      country: 'US',
      state: 'CA',
      consent_to_marketing: '1'
    }
  end

  subject(:service) { described_class.new(params: params, user: user) }

  describe '#execute' do
    it 'returns an error response' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq('Not implemented')
    end
  end
end
