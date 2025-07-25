# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'user/registrations_identity_verification/show', feature_category: :instance_resiliency do
  let_it_be(:template) { 'users/registrations_identity_verification/show' }
  let_it_be(:user) { create_default(:user) }
  let(:trial_registration) { false }

  before do
    assign(:user, user)
    allow(view).to receive(:trial_registration?).and_return(trial_registration)
  end

  it_behaves_like 'page with unconfirmed user deletion information'

  context 'with lightweight_trial_registration_redesign experiment' do
    let(:onboarding_status_presenter) do
      instance_double(::Onboarding::StatusPresenter, tracking_label: 'trial_registration',
        new_registration_design?: true)
    end

    let(:trial_registration) { true }

    before do
      allow(view).to receive(:onboarding_status_presenter).and_return(onboarding_status_presenter)
    end

    it 'sets content_for hide_empty_navbar to true when experiment is candidate' do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)

      render(template: template)

      expect(view.content_for(:hide_empty_navbar)).to be_truthy
    end

    it 'does not set content_for hide_empty_navbar' do
      stub_experiments(lightweight_trial_registration_redesign: :control)

      render(template: template)

      expect(view.content_for(:hide_empty_navbar)).to be_falsey
    end
  end
end
