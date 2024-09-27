# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/new', feature_category: :acquisition do
  let(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }

  before do
    allow(view).to receive(:arkose_labs_enabled?).and_return(false)
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:preregistration_tracking_label).and_return('trial_registration')
    view.lookup_context.prefixes << 'devise/registrations'
  end

  subject { render && rendered }

  it { is_expected.to have_content(s_('InProductMarketing|Free 60-day trial GitLab Ultimate & GitLab Duo Enterprise')) }
  it { is_expected.to have_content(s_('InProductMarketing|No credit card required.')) }
  it { is_expected.to have_content(s_('InProductMarketing|One platform for Dev, Sec, and Ops teams')) }

  it { is_expected.to have_content(s_('InProductMarketing|Want to host GitLab on your servers?')) }
  it { is_expected.to have_link(s_('InProductMarketing|Start a Self-Managed trial'), href: 'https://about.gitlab.com/free-trial/#selfmanaged/') }

  context 'when duo_enterprise_trials_registration feature flag is disabled' do
    before do
      stub_feature_flags(duo_enterprise_trials_registration: false)
    end

    it { is_expected.to have_content(s_('InProductMarketing|Free 30-day trial GitLab Ultimate')) }
    it { is_expected.to have_content(s_('InProductMarketing|Accelerate your digital transformation')) }
  end

  context 'for password form' do
    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true)
    end

    it do
      is_expected.to have_css('form[action="/-/trial_registrations?glm_content=_glm_content_&glm_source=_glm_source_"]')
    end
  end

  context 'for omniauth provider buttons' do
    let(:action_params) { 'glm_content=_glm_content_&glm_source=_glm_source_&trial=true' }

    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true) # for trials this view it isn't reachable in the false case
    end

    it { is_expected.to have_css("form[action='/users/auth/github?#{action_params}']") }
    it { is_expected.to have_css("form[action='/users/auth/google_oauth2?#{action_params}']") }
  end
end
