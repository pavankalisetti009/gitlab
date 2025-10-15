<script>
import { GlCard, GlProgressBar, GlSprintf } from '@gitlab/ui';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { USAGE_DANGER_THRESHOLD, USAGE_WARNING_THRESHOLD } from '../constants';
import HumanTimeframeWithDaysRemaining from './human_timeframe_with_days_remaining.vue';

export default {
  name: 'CurrentUsageCard',
  components: {
    GlCard,
    GlProgressBar,
    GlSprintf,
    HumanTimeframeWithDaysRemaining,
  },
  props: {
    poolCreditsUsed: {
      type: Number,
      required: true,
    },
    poolTotalCredits: {
      type: Number,
      required: true,
    },
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
  computed: {
    totalCreditsUsed() {
      return this.poolCreditsUsed + this.overageCreditsUsed;
    },
    usagePercentage() {
      if (this.poolTotalCredits === 0) return 0;
      return ((this.totalCreditsUsed / this.poolTotalCredits) * 100).toFixed(1);
    },
    poolCreditsRemaining() {
      return this.poolTotalCredits - this.poolCreditsUsed;
    },
    progressBarVariant() {
      if (this.usagePercentage >= USAGE_DANGER_THRESHOLD) {
        return 'danger';
      }

      if (this.usagePercentage >= USAGE_WARNING_THRESHOLD) {
        return 'warning';
      }

      return 'primary';
    },
  },
  methods: {
    numberToMetricPrefix,
  },
  totalCreditsSeparator: '/ ',
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent">
    <h2 class="gl-font-heading gl-my-3 gl-text-size-h2">
      {{ s__('UsageBilling|Current month usage') }}
    </h2>
    <p>
      <human-timeframe-with-days-remaining
        :month-start-date="monthStartDate"
        :month-end-date="monthEndDate"
      />
    </p>
    <div class="gl-flex gl-flex-row gl-justify-between">
      <span class="gl-text-size-h2 gl-font-bold" data-testid="total-credits-used">
        {{ numberToMetricPrefix(totalCreditsUsed) }}
      </span>
      <span class="gl-text-size-h2 gl-font-bold gl-text-gray-500" data-testid="pool-total-credits">
        {{ $options.totalCreditsSeparator }}
        {{ numberToMetricPrefix(poolTotalCredits) }}
      </span>
    </div>
    <gl-progress-bar
      :value="usagePercentage"
      :variant="progressBarVariant"
      class="gl-mb-5 gl-mt-1 gl-h-5"
    />
    <div class="gl-font-sm gl-flex gl-flex-col gl-gap-3">
      <div class="gl-flex gl-flex-row gl-justify-between">
        <span data-testid="percentage-utilized">
          <gl-sprintf :message="s__('UsageBilling|%{percentage}%{percentSymbol} utilized')">
            <template #percentage>{{ usagePercentage }}</template>
            <template #percentSymbol>%</template>
          </gl-sprintf>
        </span>

        <span data-testid="pool-credits-remaining">
          <gl-sprintf
            :message="
              n__(
                'UsageBilling|%{poolCreditsRemaining} pool credit remaining',
                'UsageBilling|%{poolCreditsRemaining} pool credits remaining',
                poolCreditsRemaining,
              )
            "
          >
            <template #poolCreditsRemaining>{{
              numberToMetricPrefix(poolCreditsRemaining)
            }}</template>
          </gl-sprintf>
        </span>
      </div>
      <div class="gl-flex gl-flex-row gl-justify-between">
        <span>{{ s__('UsageBilling|Current overage') }}</span>
        <span data-testid="overage-credits-used">{{
          numberToMetricPrefix(overageCreditsUsed)
        }}</span>
      </div>
    </div>
  </gl-card>
</template>
