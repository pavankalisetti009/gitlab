# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterpriseAlert
    class PremiumComponent < BaseComponent
      private

      def render?
        namespace.premium_plan? && GitlabSubscriptions::Duo.no_add_on_purchase_for_namespace?(namespace)
      end

      def body
        [
          s_('BillingPlans|Start an Ultimate trial with GitLab Duo Enterprise to ' \
            'try the complete set of features from GitLab. GitLab Duo Enterprise ' \
            'gives you access to the full product offering from GitLab, ' \
            'including AI-powered features.'),
          s_('BillingPlans|Not ready to trial the full suite of GitLab and ' \
            'GitLab Duo features? Start a free trial of GitLab Duo Pro instead.')
        ]
      end

      def secondary_cta_options
        {
          href: new_trials_duo_pro_path(namespace_id: namespace.id),
          category: 'secondary',
          variant: 'confirm',
          button_options: {
            class: 'gl-w-full sm:gl-w-auto',
            data: {
              event_tracking: 'click_duo_enterprise_trial_billing_page',
              event_label: 'duo_pro_trial'
            }
          }
        }
      end

      def secondary_cta
        s_('BillingPlans|Try GitLab Duo Pro')
      end
    end
  end
end
