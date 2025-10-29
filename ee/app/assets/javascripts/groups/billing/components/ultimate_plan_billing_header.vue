<script>
import { GlBadge, GlButton } from '@gitlab/ui';

export default {
  name: 'UltimatePlanBillingHeader',
  components: {
    GlBadge,
    GlButton,
  },
  props: {
    trialActive: {
      type: Boolean,
      required: true,
    },
    upgradeToUltimateUrl: {
      type: String,
      required: true,
    },
    ctaLabel: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-mt-5 gl-flex-1 gl-p-6 md:gl-border-l md:gl-mt-0">
    <div class="gl-flex gl-justify-between">
      <span class="gl-text-size-h1-xl gl-font-bold">{{ __('Ultimate') }}</span>

      <div v-if="trialActive" class="gl-self-center">
        <gl-badge class="!gl-bg-strong">
          <span class="gl-text-subtle">{{ s__('BillingPlans|Currently trialing') }}</span>
        </gl-badge>
      </div>
    </div>

    <div class="gl-mt-5 gl-text-subtle md:gl-mt-0">
      {{
        s__(
          'BillingPlans|Start free with advanced enterprise security and compliance, no credit card required.',
        )
      }}
    </div>

    <gl-button
      class="gl-mb-2 gl-mt-5 gl-w-full"
      data-track-action="click_button"
      data-track-label="plan_cta"
      data-track-property="ultimate"
      :href="upgradeToUltimateUrl"
      referrerpolicy="no-referrer-when-downgrade"
      >{{ ctaLabel }}
    </gl-button>
  </div>
</template>
