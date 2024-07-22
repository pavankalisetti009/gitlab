# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitlabSubscriptions::DuoProCardComponent, :saas, :aggregate_failures, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let(:user) { build_stubbed(:user) }
  let(:namespace) { build_stubbed(:namespace) }

  subject(:component) { described_class.new(namespace: namespace, user: user) }

  before do
    render_inline(component)
  end

  context 'when there is an active add-on purchase for the namespace' do
    before do
      allow(GitlabSubscriptions::DuoPro)
        .to receive(:no_active_add_on_purchase_for_namespace?).with(namespace).and_return(false)
    end

    it 'does not render' do
      expect(page).to have_content('')
    end
  end

  context 'when there is no active add-on purchase for the namespace' do
    it 'renders the component' do
      data_attributes = {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json,
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'tertiary',
          variant: 'confirm'
        }.to_json
      }

      expect(page).to have_content(s_('CodeSuggestions|Introducing the GitLab Duo Pro add-on'))
      msg = 'Boost productivity across the software development life cycle by using ' \
        'Code Suggestions and GitLab Duo Chat'
      expect(page).to have_content(msg)
      expect(page).to have_content(_('You can now try GitLab Duo Pro for free for 60 days'))
      expect(page).to have_link('GitLab Duo Pro', href: 'https://about.gitlab.com/gitlab-duo/')
      expect(page)
        .to have_link('Start a free GitLab Duo Pro trial', href: new_trials_duo_pro_path(namespace_id: namespace.id))

      data_attributes.each do |attribute, value|
        expect_hand_raise_data_attribute(attribute, value)
      end
    end

    def expect_hand_raise_data_attribute(attribute, value)
      expect(page).to have_selector(".js-hand-raise-lead-trigger[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
