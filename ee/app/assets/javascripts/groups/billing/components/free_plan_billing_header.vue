<script>
import { GlBadge } from '@gitlab/ui';

export default {
  name: 'FreePlanBillingHeader',
  components: {
    GlBadge,
  },
  props: {
    trialActive: {
      type: Boolean,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-mt-5 gl-p-6 md:gl-mt-0">
    <div class="gl-flex gl-justify-between">
      <span class="gl-text-size-h1-xl gl-font-bold">{{ __('Free') }}</span>

      <div v-if="!trialActive" class="gl-self-center">
        <gl-badge class="!gl-bg-strong">
          <span class="gl-text-subtle">{{ s__('BillingPlans|Current subscription') }}</span>
        </gl-badge>
      </div>
    </div>

    <div class="gl-mb-3 gl-mt-5 gl-text-subtle md:gl-mt-0">
      {{
        s__(
          'BillingPlans|For individuals working on personal projects and open source contributions.',
        )
      }}
    </div>
  </div>
</template>
