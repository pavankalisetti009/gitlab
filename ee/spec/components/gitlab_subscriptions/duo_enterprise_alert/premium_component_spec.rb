# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterpriseAlert::PremiumComponent, :saas, :aggregate_failures,
  type: :component, feature_category: :acquisition do
  let(:namespace) { build(:group, id: non_existing_record_id) }
  let(:user) { build(:user) }

  subject(:component) do
    render_inline(described_class.new(namespace: namespace, user: user)) && page
  end

  before do
    build(:gitlab_subscription, :premium, namespace: namespace)
  end

  context 'when gold plan' do
    before do
      build(:gitlab_subscription, :gold, namespace: namespace)
    end

    it { is_expected.to have_content('') }
  end

  context 'when there is Duo add-on' do
    before do
      allow(GitlabSubscriptions::Duo)
        .to receive(:no_add_on_purchase_for_namespace?)
        .with(namespace)
        .and_return(false)
    end

    it { is_expected.to have_content('') }
  end

  context 'when rendering' do
    it 'has the correct text' do
      is_expected.to have_content(
        'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise'
      )

      is_expected.to have_content(
        'Start an Ultimate trial with GitLab Duo Enterprise to try the ' \
          'complete set of features from GitLab. GitLab Duo Enterprise gives ' \
          'you access to the full product offering from GitLab, including ' \
          'AI-powered features.'
      )

      is_expected.to have_content(
        'Not ready to trial the full suite of GitLab and GitLab Duo features? ' \
          'Start a free trial of GitLab Duo Pro instead.'
      )
    end

    it 'has the primary action' do
      is_expected.to have_link(
        'Start free trial of GitLab Ultimate and GitLab Duo Enterprise',
        href: new_trial_path(namespace_id: namespace.id)
      )

      is_expected.to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="ultimate_and_duo_enterprise_trial"]'
      )
    end

    it 'has the secondary action' do
      is_expected.to have_link(
        'Try GitLab Duo Pro', href: new_trials_duo_pro_path(namespace_id: namespace.id)
      )

      is_expected.to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="duo_pro_trial"]'
      )
    end
  end
end
