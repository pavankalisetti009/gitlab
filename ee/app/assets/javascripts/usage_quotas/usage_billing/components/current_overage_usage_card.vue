<script>
import { GlCard, GlLink, GlSprintf } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import HumanTimeframeWithDaysRemaining from './human_timeframe_with_days_remaining.vue';

export default {
  name: 'CurrentOverageUsageCard',
  components: {
    GlCard,
    GlLink,
    GlSprintf,
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
  pricingLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent">
    <h2 class="gl-font-heading gl-my-3 gl-text-size-h2">
      {{ s__('UsageBilling|On-demand credits used this billable month') }}
    </h2>
    <p>
      <human-timeframe-with-days-remaining
        :month-start-date="monthStartDate"
        :month-end-date="monthEndDate"
      />
    </p>

    <div>
      <span class="gl-text-size-h2 gl-font-bold" data-testid="overage-credits-used">
        {{ numberToMetricPrefix(overageCreditsUsed) }}
      </span>
    </div>

    <p class="gl-mt-auto">
      {{
        s__(
          'UsageBilling|These are credits consumed beyond your users included credits, charged at standard on-demand rates.',
        )
      }}
      <gl-sprintf
        :message="
          s__('UsageBilling|Learn more about %{helpLinkStart}GitLab Credit pricing%{helpLinkEnd}.')
        "
      >
        <template #helpLink="{ content }">
          <gl-link :href="$options.pricingLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
  </gl-card>
</template>
