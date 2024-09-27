# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/_duo_free_access_ending_banner.html.haml', :saas, feature_category: :acquisition do
  let(:show_duo_free_access_ending_banner?) { true }
  let(:namespace) { build(:namespace, id: non_existing_record_id) }
  let(:sub_group) { build(:group, parent: namespace) }

  before do
    allow(view)
      .to receive(:show_duo_free_access_ending_banner?).with(namespace).and_return(show_duo_free_access_ending_banner?)
    allow(view).to receive(:resource).and_return(sub_group)
  end

  subject(:page_level_alert) { view.content_for(:page_level_alert) }

  context 'when the banner does not show' do
    let(:show_duo_free_access_ending_banner?) { false }

    it 'does not render anything' do
      expect { render }.to raise_error(TypeError)
    end
  end

  context 'when the banner shows' do
    before do
      render
    end

    it 'contains the correct header and content' do
      expect(page_level_alert).to have_content('Free access to GitLab Duo is ending on 2024-10-17')

      expect(page_level_alert).to have_content(
        'Starting October 17, 2024, all GitLab Duo features, including Duo Chat, require a paid add-on subscription. ' \
          'To ensure uninterrupted access to Code Suggestions and Chat, buy Duo Pro and assign seats to your users. ' \
          'Or, for Duo Enterprise options, contact Sales. Buy Duo Pro')

      expect(page_level_alert).to have_link('require a paid add-on subscription.',
        href: help_page_path('subscriptions/subscription-add-ons.md',
          anchor: 'changes-to-gitlab-duo-pro-and-gitlab-duo-enterprise-access'))
    end

    context 'with the Buy Duo Pro button' do
      it 'contains a link to customers dot portal' do
        expect(page_level_alert)
          .to have_link('Buy Duo Pro', href: subscription_portal_add_saas_duo_pro_seats_url(namespace.id))
      end
    end

    context 'with the Contact Sales button' do
      it 'contains the hand raise lead selector' do
        expect(page_level_alert).to have_selector('.js-hand-raise-lead-trigger')
      end
    end
  end
end
