<script>
import { GlBadge, GlButton } from '@gitlab/ui';

export default {
  name: 'PremiumPlanBillingHeader',
  components: {
    GlBadge,
    GlButton,
  },
  props: {
    upgradeToPremiumUrl: {
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
  <div class="gl-mt-5 gl-flex-1 gl-p-6 md:gl-mt-0">
    <div class="gl-flex gl-justify-between">
      <span class="gl-text-size-h1-xl gl-font-bold">{{ __('Premium') }}</span>

      <div class="gl-self-center">
        <gl-badge variant="info">{{ s__('BillingPlans|Recommended') }}</gl-badge>
      </div>
    </div>

    <div class="gl-mt-5 gl-text-subtle md:gl-mt-0">
      {{
        s__(
          'BillingPlans|For scaling organizations seeking enhanced productivity and collaboration.',
        )
      }}
    </div>

    <gl-button
      variant="confirm"
      class="gl-mb-2 gl-mt-5 gl-w-full"
      data-track-action="click_button"
      data-track-label="plan_cta"
      data-track-property="premium"
      :href="upgradeToPremiumUrl"
      referrerpolicy="no-referrer-when-downgrade"
      >{{ ctaLabel }}
    </gl-button>
  </div>
</template>
