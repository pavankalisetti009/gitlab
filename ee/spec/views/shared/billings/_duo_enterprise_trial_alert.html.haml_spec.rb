# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/billings/_duo_enterprise_trial_alert.html.haml', :saas, feature_category: :acquisition do
  let(:group) { build(:group, id: non_existing_record_id) }

  before do
    allow(view).to receive(:current_user)
  end

  def render
    super(partial: 'shared/billings/duo_enterprise_trial_alert', locals: { namespace: group })
  end

  context 'when ultimate plan' do
    before do
      build(:gitlab_subscription, :ultimate, namespace: group)
    end

    it 'contains the correct text' do
      render

      expect(rendered).to have_content('Introducing GitLab Duo Enterprise')

      expect(rendered).to have_content(
        'Start a GitLab Duo Enterprise trial to try all end-to-end AI ' \
          'capabilities from GitLab. You can try it for free for 60 days, ' \
          'no credit card required.'
      )
    end

    it 'contains the primary action' do
      render

      expect(rendered).to have_link(
        'Start a free GitLab Duo Enterprise Trial',
        href: new_trials_duo_enterprise_path(namespace_id: group.id)
      )

      expect(rendered).to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="duo_enterprise_trial"]'
      )
    end

    it 'contains the hand raise lead selector' do
      render

      expect(rendered).to have_selector('.js-hand-raise-lead-trigger')
    end
  end

  context 'when premium plan' do
    before do
      build(:gitlab_subscription, :premium, namespace: group)
    end

    it 'contains the correct text' do
      render

      expect(rendered).to have_content(
        'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise'
      )

      expect(rendered).to have_content(
        'Start an Ultimate trial with GitLab Duo Enterprise to try the ' \
          'complete set of features from GitLab. GitLab Duo Enterprise gives ' \
          'you access to the full product offering from GitLab, including ' \
          'AI-powered features.'
      )

      expect(rendered).to have_content(
        'Not ready to trial the full suite of GitLab and GitLab Duo features? ' \
          'Start a free trial of GitLab Duo Pro instead.'
      )
    end

    it 'contains the primary action' do
      render

      expect(rendered).to have_link(
        'Start free trial of GitLab Ultimate and GitLab Duo Enterprise',
        href: new_trial_path(namespace_id: group.id)
      )

      expect(rendered).to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="ultimate_and_duo_enterprise_trial"]'
      )
    end

    it 'contains the secondary action' do
      render

      expect(rendered).to have_link(
        'Try GitLab Duo Pro', href: new_trials_duo_pro_path(namespace_id: group.id)
      )

      expect(rendered).to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="duo_pro_trial"]'
      )
    end
  end

  context 'when free plan' do
    before do
      build(:gitlab_subscription, :free, namespace: group)
    end

    it 'contains the correct text' do
      render

      expect(rendered).to have_content(
        'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise'
      )

      expect(rendered).to have_content(
        'Start an Ultimate trial with GitLab Duo Enterprise to try the ' \
          'complete set of features from GitLab. GitLab Duo Enterprise gives ' \
          'you access to the full product offering from GitLab, including ' \
          'AI-powered features. You can try it for free, no credit card required.'
      )
    end

    it 'contains the primary action' do
      render

      expect(rendered).to have_link(
        'Start free trial of GitLab Ultimate and GitLab Duo Enterprise',
        href: new_trial_path(namespace_id: group.id)
      )

      expect(rendered).to have_css(
        '[data-event-tracking="click_duo_enterprise_trial_billing_page"]' \
          '[data-event-label="ultimate_and_duo_enterprise_trial"]'
      )
    end

    it 'contains the hand raise lead selector' do
      render

      expect(rendered).to have_selector('.js-hand-raise-lead-trigger')
    end
  end
end
