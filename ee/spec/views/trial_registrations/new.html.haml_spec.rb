# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/new.html.haml', feature_category: :acquisition do
  let_it_be(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }

  before do
    allow(view).to receive(:arkose_labs_enabled?).and_return(false)
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:glm_tracking_params).and_return({})
    allow(view).to receive(:preregistration_tracking_label).and_return('trial_registration')
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
end
