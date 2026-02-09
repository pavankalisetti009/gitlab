# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/_new', feature_category: :acquisition do
  let(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  before do
    allow(view).to receive_messages(
      onboarding_status_presenter: onboarding_status_presenter,
      arkose_labs_enabled?: false,
      resource: resource,
      resource_name: :user,
      preregistration_tracking_label: 'trial_registration'
    )
    view.lookup_context.prefixes << 'devise/registrations'
    assign(:trial_duration, 30)
  end

  subject { render && rendered }

  context 'when premium_trial_positioning experiment' do
    context 'when premium_trial_positioning is control' do
      before do
        stub_experiments(premium_trial_positioning: :control)
      end

      it { is_expected.to have_content('Enjoy 30 days of full access to our best plan') }
      it { is_expected.to have_content(s_('InProductMarketing|One platform for Dev, Sec, and Ops teams')) }
      it { is_expected.to have_content(s_('InProductMarketing|End-to-end security and compliance')) }
      it { is_expected.to have_content(s_('InProductMarketing|Boost efficiency and collaboration')) }
      it { is_expected.to have_content(s_('InProductMarketing|Ship secure software faster')) }

      context 'when feature flag `ultimate_trial_with_dap` is disabled' do
        before do
          stub_feature_flags(ultimate_trial_with_dap: false)
        end

        it 'shows GitLab Duo Agent Platform feature' do
          is_expected.to have_content(
            s_('InProductMarketing|GitLab Duo Enterprise: AI across the software development lifecycle')
          )
        end
      end

      context 'when feature flag `ultimate_trial_with_dap` is enabled' do
        it 'shows GitLab Duo Agent Platform feature' do
          is_expected.to have_content(
            s_('InProductMarketing|GitLab Duo Agent Platform: AI across the software development lifecycle')
          )
        end
      end
    end

    context 'when premium_trial_positioning is candidate' do
      before do
        stub_experiments(premium_trial_positioning: :candidate)
      end

      it { is_expected.to have_content('Enjoy 30 days of full access to Premium') }
      it { is_expected.to have_content(s_('InProductMarketing|AI Chat in the IDE')) }
      it { is_expected.to have_content(s_('InProductMarketing|AI Code Suggestions in the IDE')) }
      it { is_expected.to have_content(s_('InProductMarketing|Release Controls')) }
      it { is_expected.to have_content(s_('InProductMarketing|Team Project Management')) }
      it { is_expected.to have_content(s_('InProductMarketing|Unlimited Licensed Users')) }
    end
  end
end
