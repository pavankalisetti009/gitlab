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
  <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-p-5">
    <h2 class="gl-heading-scale-400 gl-mb-3">
      {{ s__('UsageBilling|GitLab Credits - On Demand') }}
    </h2>
    <p>
      <human-timeframe-with-days-remaining
        :month-start-date="monthStartDate"
        :month-end-date="monthEndDate"
      />
    </p>

    <div class="gl-mb-3">
      <span class="gl-heading-scale-600 gl-font-bold" data-testid="overage-credits-used">
        {{ numberToMetricPrefix(overageCreditsUsed) }}
      </span>
    </div>

    <p class="gl-border-t gl-mb-0 gl-mt-auto gl-pt-3 gl-text-sm gl-text-subtle">
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
