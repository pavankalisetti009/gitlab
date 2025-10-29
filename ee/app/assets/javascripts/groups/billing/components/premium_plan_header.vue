<script>
import { GlIcon, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'PremiumPlanHeader',
  components: {
    GlIcon,
    GlButton,
  },
  props: {
    trialActive: {
      type: Boolean,
      required: true,
    },
    trialExpired: {
      type: Boolean,
      required: true,
    },
    startTrialPath: {
      type: String,
      required: true,
    },
    upgradeToPremiumUrl: {
      type: String,
      required: true,
    },
  },
  computed: {
    attributes() {
      if (this.trialActive) {
        return {
          header: s__('BillingPlans|Level up with Premium'),
          subheader: s__(
            "BillingPlans|Don't lose access to advanced features, make the switch now to maintain your team's productivity gains.",
          ),
          lastAdvantage: s__('BillingPlans|Team Project Management'),
          ctaLabel: s__('BillingPlans|Choose Premium'),
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      if (this.trialExpired) {
        return {
          header: s__('BillingPlans|Level up with Premium'),
          subheader: s__(
            "BillingPlans|Upgrade and unlock advanced features that boost your team's productivity instantly.",
          ),
          lastAdvantage: s__('BillingPlans|Team Project Management'),
          ctaLabel: s__('BillingPlans|Upgrade to Premium'),
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      return {
        header: s__(
          'BillingPlans|Get the most out of GitLab with Ultimate and GitLab Duo Enterprise',
        ),
        subheader: s__(
          'BillingPlans|Start an Ultimate trial with GitLab Duo Enterprise to try the complete set of features from GitLab.',
        ),
        lastAdvantage: s__('BillingPlans|No credit card required'),
        ctaLabel: s__('BillingPlans|Start free trial'),
        ctaHref: this.startTrialPath,
        ctaTrackingData: {
          'data-event-tracking': 'click_duo_enterprise_trial_billing_page',
          'data-event-label': 'ultimate_and_duo_enterprise_trial',
        },
      };
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex-1 gl-rounded-b-lg gl-border-t-0 gl-bg-subtle gl-p-6 md:gl-border-t md:gl-rounded-l-none md:gl-rounded-r-lg md:gl-border-l-0"
  >
    <div>
      <h3 class="gl-heading-3-fixed gl-mb-3 gl-text-default">
        {{ attributes.header }}
      </h3>

      <div class="gl-text-sm gl-text-subtle">
        {{ attributes.subheader }}
      </div>

      <div class="gl-mt-3">
        <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
        <span class="gl-text-sm">{{ s__('BillingPlans|AI Chat in the IDE') }}</span>
      </div>

      <div class="gl-mt-3">
        <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
        <span class="gl-text-sm">{{ s__('BillingPlans|AI Code Suggestions in the IDE') }}</span>
      </div>

      <div class="gl-mt-3">
        <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
        <span class="gl-text-sm">{{ s__('BillingPlans|Advanced CI/CD') }}</span>
      </div>

      <div class="gl-mt-3">
        <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
        <span class="gl-text-sm">{{ attributes.lastAdvantage }}</span>
      </div>
    </div>

    <div class="gl-mt-5 gl-flex-row">
      <gl-button
        category="secondary"
        v-bind="attributes.ctaTrackingData"
        :href="attributes.ctaHref"
        referrerpolicy="no-referrer-when-downgrade"
        >{{ attributes.ctaLabel }}
      </gl-button>
    </div>
  </div>
</template>
