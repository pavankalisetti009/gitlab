# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/new', feature_category: :system_access do
  let(:arkose_labs_enabled) { true }
  let(:arkose_labs_api_key) { "api-key" }
  let(:arkose_labs_domain) { "domain" }
  let(:resource) { Users::RegistrationsBuildService.new(nil, {}).execute }

  subject { render && rendered }

  before do
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:registration_path_params).and_return({})

    allow(view).to receive(:glm_tracking_params).and_return({})
    allow(view).to receive(:arkose_labs_enabled?).and_return(arkose_labs_enabled)
    allow(view).to receive(:preregistration_tracking_label).and_return('free_registration')
    allow(::Arkose::Settings).to receive(:arkose_public_api_key).and_return(arkose_labs_api_key)
    allow(::Arkose::Settings).to receive(:arkose_labs_domain).and_return(arkose_labs_domain)
  end

  it { is_expected.to have_selector('#js-arkose-labs-challenge') }
  it { is_expected.to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
  it { is_expected.to have_selector("[data-domain='#{arkose_labs_domain}']") }

  context 'when the feature is disabled' do
    let(:arkose_labs_enabled) { false }

    it { is_expected.not_to have_selector('#js-arkose-labs-challenge') }
    it { is_expected.not_to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
    it { is_expected.not_to have_selector("[data-domain='#{arkose_labs_domain}']") }
  end
end
