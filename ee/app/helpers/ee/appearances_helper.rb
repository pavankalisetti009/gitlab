# frozen_string_literal: true

module EE
  module AppearancesHelper
    extend ::Gitlab::Utils::Override

    override :default_brand_title
    def default_brand_title
      _('GitLab Enterprise Edition')
    end

    override :brand_title
    def brand_title
      return super unless ::Onboarding.enabled?

      case request.path
      when new_user_session_path
        sign_in_page_title
      when new_user_registration_path
        sign_up_page_title
      else
        super
      end
    end

    def sign_in_page_title
      _("Sign in to GitLab")
    end

    def sign_up_page_title
      _("Get started with GitLab")
    end
  end
end
