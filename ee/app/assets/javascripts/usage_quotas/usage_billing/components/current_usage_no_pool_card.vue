<script>
import { GlCard } from '@gitlab/ui';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import HumanTimeframeWithDaysRemaining from './human_timeframe_with_days_remaining.vue';

export default {
  name: 'CurrentUsageNoPoolCard',
  components: {
    GlCard,
    HumanTimeframeWithDaysRemaining,
  },
  props: {
    overageCreditsUsed: {
      type: Number,
      required: true,
    },
    monthStartDate: {
      type: String,
      required: true,
    },
    monthEndDate: {
      type: String,
      required: true,
    },
  },
  methods: {
    numberToMetricPrefix,
  },
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent">
    <h2 class="gl-font-heading gl-my-3 gl-text-size-h2">
      {{ s__('UsageBilling|Current month on demand usage') }}
    </h2>
    <p>
      <human-timeframe-with-days-remaining
        :month-start-date="monthStartDate"
        :month-end-date="monthEndDate"
      />
    </p>
    <div class="gl-flex gl-flex-row gl-justify-between">
      <span>{{ s__('UsageBilling|Current overage') }}</span>
      <span data-testid="overage-credits-used">{{ numberToMetricPrefix(overageCreditsUsed) }}</span>
    </div>
  </gl-card>
</template>
