# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/_new_lightweight', feature_category: :acquisition do
  let(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  let(:social_signin_enabled) { false }

  before do
    allow(view).to receive_messages(
      onboarding_status_presenter: onboarding_status_presenter,
      arkose_labs_enabled?: false,
      resource: resource,
      resource_name: :user,
      preregistration_tracking_label: 'trial_registration',
      social_signin_enabled?: social_signin_enabled
    )
    view.lookup_context.prefixes << 'devise/registrations'
    assign(:trial_duration, 30)
  end

  it 'sets content_for hide_empty_navbar to true' do
    render

    expect(view.content_for(:hide_empty_navbar)).to be_truthy
  end

  context 'when social signin is disabled' do
    it 'does not render social signin section' do
      render

      expect(rendered).not_to have_content(_('Continue with:'))
    end
  end

  context 'when social signin is enabled' do
    let(:social_signin_enabled) { true }

    before do
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
    end

    it 'renders social signin section' do
      render

      expect(rendered).to have_content(_('or'))
      expect(rendered).to have_content(_('Continue with:'))
    end
  end
end
