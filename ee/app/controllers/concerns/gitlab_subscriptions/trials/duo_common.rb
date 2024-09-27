# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoCommon
      extend ActiveSupport::Concern

      include OneTrustCSP
      include GoogleAnalyticsCSP
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper

      included do
        layout 'minimal'

        skip_before_action :set_confirm_warning

        before_action :check_feature_available!
        before_action :check_trial_eligibility!
      end

      def check_trial_eligibility!
        return if eligible_namespaces_exist?

        render 'gitlab_subscriptions/trials/duo/access_denied', status: :forbidden
      end

      def eligible_namespaces_exist?
        return false if eligible_namespaces.none?

        GitlabSubscriptions::Trials::AddOns.eligible_namespace?(general_params[:namespace_id], eligible_namespaces)
      end

      def namespace
        current_user.owned_groups.find_by_id(general_params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def general_params
        params.permit(:namespace_id, :step)
      end

      def lead_params
        params.permit(
          *::Onboarding::Status::GLM_PARAMS,
          :company_name, :company_size, :first_name, :last_name, :phone_number,
          :country, :state, :website_url
        ).to_h
      end

      def success_doc_link
        assign_doc_url = helpers.help_page_path(
          'subscriptions/subscription-add-ons', anchor: 'assign-gitlab-duo-seats'
        )
        assign_link = helpers.link_to('', assign_doc_url, target: '_blank', rel: 'noopener noreferrer')
        tag_pair(assign_link, :assign_link_start, :assign_link_end)
      end
    end
  end
end
