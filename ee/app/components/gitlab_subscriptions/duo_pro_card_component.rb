# frozen_string_literal: true

module GitlabSubscriptions
  class DuoProCardComponent < ViewComponent::Base
    include SafeFormatHelper

    # @param [Namespace or Group] namespace
    # @param [User] user

    def initialize(namespace:, user:)
      @namespace = namespace
      @user = user
    end

    private

    attr_reader :namespace, :user

    delegate :sprite_icon, to: :helpers

    def render?
      GitlabSubscriptions::DuoPro.no_active_add_on_purchase_for_namespace?(namespace)
    end

    def hand_raise_lead_data
      {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'tertiary',
          variant: 'confirm'
        }.to_json,
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json
      }
    end

    def card_text
      safe_format(
        s_(
          "CodeSuggestions|Boost productivity across the software development life cycle by using " \
            "Code Suggestions and GitLab Duo Chat as part of the %{duoLinkStart}GitLab Duo Pro%{duoLinkEnd} " \
            "add-on. You can now try GitLab Duo Pro for free for %{days} days, no credit card required."
        ),
        {
          days: GitlabSubscriptions::Trials::DuoPro::DURATION_NUMBER
        },
        tag_pair(duo_pro_info_link, :duoLinkStart, :duoLinkEnd)
      )
    end

    def duo_pro_info_link
      link_to('', 'https://about.gitlab.com/gitlab-duo/', target: '_blank', rel: 'noopener noreferrer')
    end
  end
end
