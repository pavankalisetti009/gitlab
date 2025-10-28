# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User interacts with explore duo core banner", :js, feature_category: :activation do
  shared_examples 'dismissals' do
    it 'dismisses the banner when clicking the close button' do
      expect(page).to have_content(banner_content)

      close_promotion_popover unless Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout

      page.within('.explore-duo-core-banner') do
        find('.gl-banner-close').click
        # Need to wait for requests or else the queries from this request will get
        # added to the query transaction count and overflow the limit
        wait_for_all_requests
      end

      expect_banner_dismissed
    end

    it 'dismisses the banner when clicking the CTA' do
      expect(page).to have_content(banner_content)

      close_promotion_popover unless Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout

      page.within('.explore-duo-core-banner') do
        click_link 'Explore GitLab Duo Core'
        wait_for_all_requests
      end

      expect_banner_dismissed
    end

    def banner_content
      'You now have access to GitLab Duo Chat and Code Suggestions in supported IDEs.'
    end

    def expect_banner_dismissed
      expect(page).not_to have_content(banner_content)

      visit(merge_request_path(merge_request))

      expect(page).not_to have_content(banner_content)
    end
  end

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, assignees: [user]) }

  before_all do
    project.add_developer(user)
  end

  # Banner not showing for self-managed
  context 'for self-managed', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/577871' do
    before do
      stub_licensed_features(code_suggestions: true, ai_chat: true)
      ::Ai::Setting.instance.update!(duo_core_features_enabled: true)

      sign_in(user)

      visit(merge_request_path(merge_request))
    end

    it_behaves_like 'dismissals'
  end

  context 'for gitlab.com', :saas do
    let_it_be(:duo_core_provision) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group) }

    before_all do
      group.update!(duo_core_features_enabled: true)
    end

    before do
      sign_in(user)

      visit(merge_request_path(merge_request))
    end

    it_behaves_like 'dismissals'
  end

  def close_promotion_popover
    within_testid('duo-chat-promo-callout-popover') do
      find_by_testid('close-button').click
    end
  end
end
