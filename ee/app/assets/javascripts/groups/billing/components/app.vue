<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import { s__ } from '~/locale';
import CurrentPlanHeader from './current_plan_header.vue';
import PremiumPlanHeader from './premium_plan_header.vue';
import FreePlanBillingHeader from './free_plan_billing_header.vue';
import FreePlanBilling from './free_plan_billing.vue';
import PremiumPlanBillingHeader from './premium_plan_billing_header.vue';
import PremiumPlanBilling from './premium_plan_billing.vue';
import UltimatePlanBillingHeader from './ultimate_plan_billing_header.vue';
import UltimatePlanBilling from './ultimate_plan_billing.vue';

export default {
  name: 'FreeTrialBillingApp',
  components: {
    GlTabs,
    GlTab,
    CurrentPlanHeader,
    PremiumPlanHeader,
    FreePlanBillingHeader,
    FreePlanBilling,
    PremiumPlanBillingHeader,
    PremiumPlanBilling,
    UltimatePlanBillingHeader,
    UltimatePlanBilling,
  },
  props: {
    seatsInUse: {
      type: Number,
      required: true,
    },
    trialActive: {
      type: Boolean,
      required: true,
    },
    trialExpired: {
      type: Boolean,
      required: true,
    },
    manageSeatsPath: {
      type: String,
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
    upgradeToUltimateUrl: {
      type: String,
      required: true,
    },
    upgradeToPremiumTrackingUrl: {
      type: String,
      required: true,
    },
    upgradeToUltimateTrackingUrl: {
      type: String,
      required: true,
    },
    totalSeats: {
      type: Number,
      required: false,
      default: 0,
    },
    trialEndsOn: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    attributes() {
      if (this.trialActive) {
        return {
          premiumCtaLabel: s__('BillingPlans|Choose Premium'),
          ultimateCtaLabel: s__('BillingPlans|Choose Ultimate'),
        };
      }

      return {
        premiumCtaLabel: s__('BillingPlans|Upgrade to Premium'),
        ultimateCtaLabel: s__('BillingPlans|Upgrade to Ultimate'),
      };
    },
  },
};
</script>
<template>
  <div class="gl-mt-8">
    <h2 class="gl-heading-2 gl-text-default">{{ s__('BillingPlans|Billing') }}</h2>

    <div class="gl-mt-8 gl-flex gl-flex-col md:gl-flex-row">
      <current-plan-header
        :seats-in-use="seatsInUse"
        :total-seats="totalSeats"
        :trial-active="trialActive"
        :trial-ends-on="trialEndsOn"
        :manage-seats-path="manageSeatsPath"
      />

      <premium-plan-header
        :trial-active="trialActive"
        :trial-expired="trialExpired"
        :start-trial-path="startTrialPath"
        :upgrade-to-premium-url="upgradeToPremiumUrl"
      />
    </div>

    <div class="gl-hidden md:gl-block">
      <div class="gl-flex gl-justify-end">
        <div
          class="gl-border gl-mt-8 gl-flex gl-basis-2/3 gl-flex-row gl-justify-center gl-rounded-t-base gl-border-b-0 gl-bg-strong gl-p-3"
        >
          <div class="gradient-star gl-mr-3 gl-mt-1 gl-h-5 gl-w-5"></div>

          <span class="gl-font-bold gl-text-strong">{{
            s__('BillingPlans|Now with AI features included')
          }}</span>
        </div>
      </div>
      <div class="gl-flex gl-bg-subtle">
        <div class="gl-border gl-basis-1/3 gl-rounded-tl-lg gl-border-b-0 gl-border-r-0">
          <free-plan-billing-header :trial-active="trialActive" />
        </div>

        <div class="gl-border gl-flex gl-basis-2/3 gl-border-b-0">
          <premium-plan-billing-header
            :upgrade-to-premium-url="upgradeToPremiumUrl"
            :cta-label="attributes.premiumCtaLabel"
            :tracking-url="upgradeToPremiumTrackingUrl"
          />

          <ultimate-plan-billing-header
            :trial-active="trialActive"
            :upgrade-to-ultimate-url="upgradeToUltimateUrl"
            :cta-label="attributes.ultimateCtaLabel"
            :tracking-url="upgradeToUltimateTrackingUrl"
          />
        </div>
      </div>
      <div class="gl-flex">
        <div class="gl-border gl-basis-1/3 gl-rounded-bl-lg gl-border-r-0">
          <free-plan-billing />
        </div>

        <div class="gl-border gl-flex gl-basis-2/3 gl-rounded-br-lg">
          <premium-plan-billing />
          <ultimate-plan-billing />
        </div>
      </div>
    </div>

    <gl-tabs class="gl-mt-5 gl-block md:gl-hidden" nav-class="gl-justify-center">
      <gl-tab :title="__('Free')">
        <div class="gl-border gl-rounded-t-lg gl-bg-subtle">
          <free-plan-billing-header :trial-active="trialActive" />
        </div>

        <div class="gl-border gl-rounded-b-lg gl-border-t-0">
          <free-plan-billing />
        </div>
      </gl-tab>

      <gl-tab :title="__('Premium')">
        <div class="gl-border gl-rounded-t-lg gl-bg-subtle">
          <premium-plan-billing-header
            :upgrade-to-premium-url="upgradeToPremiumUrl"
            :cta-label="attributes.premiumCtaLabel"
            :tracking-url="upgradeToPremiumTrackingUrl"
          />
        </div>

        <div class="gl-border gl-rounded-b-lg gl-border-t-0">
          <premium-plan-billing />
        </div>
      </gl-tab>

      <gl-tab :title="__('Ultimate')">
        <div class="gl-border gl-rounded-t-lg gl-bg-subtle">
          <ultimate-plan-billing-header
            :trial-active="trialActive"
            :upgrade-to-ultimate-url="upgradeToUltimateUrl"
            :cta-label="attributes.ultimateCtaLabel"
            :tracking-url="upgradeToUltimateTrackingUrl"
          />
        </div>

        <div class="gl-border gl-rounded-b-lg gl-border-t-0">
          <ultimate-plan-billing />
        </div>
      </gl-tab>
    </gl-tabs>
  </div>
</template>

<style scoped>
.gradient-star {
  background-image: url('gradient-star.svg?url');
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
}
</style>
