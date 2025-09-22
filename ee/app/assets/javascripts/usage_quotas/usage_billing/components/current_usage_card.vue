<script>
import { GlCard, GlProgressBar, GlSprintf } from '@gitlab/ui';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { getDayDifference } from '~/lib/utils/datetime/date_calculation_utility';
import { newDate } from '~/lib/utils/datetime_utility';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { USAGE_DANGER_THRESHOLD, USAGE_WARNING_THRESHOLD } from '../constants';

export default {
  name: 'CurrentMonthUsageCard',
  components: {
    GlCard,
    GlProgressBar,
    GlSprintf,
    HumanTimeframe,
  },
  props: {
    currentOverage: {
      type: Number,
      required: false,
      default: 0,
    },
    totalUnitsUsed: {
      type: Number,
      required: false,
      default: 0,
    },
    totalUnits: {
      type: Number,
      required: false,
      default: 0,
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
    usagePercentage() {
      if (this.totalUnits === 0) return 0;
      return ((this.totalUnitsUsed / this.totalUnits) * 100).toFixed(1);
    },
    usageRemaining() {
      return Math.max(0, this.totalUnits - this.totalUnitsUsed);
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
    daysOfMonthRemaining() {
      const today = new Date();
      const endDate = newDate(this.monthEndDate);
      const diffDays = getDayDifference(today, endDate);

      return Math.max(0, diffDays);
    },
  },
  methods: {
    numberToMetricPrefix,
  },
  totalUnitsSeparator: '/ ',
  daysRemainingSeparator: ' - ',
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent">
    <h2 class="gl-font-heading gl-my-3 gl-text-size-h2">
      {{ s__('UsageBilling|Current month usage') }}
    </h2>
    <p data-testid="date-range">
      <human-timeframe :from="monthStartDate" :till="monthEndDate" />
      <span>
        {{ $options.daysRemainingSeparator }}
        <gl-sprintf
          :message="n__('%{days} day remaining', '%{days} days remaining', daysOfMonthRemaining)"
        >
          <template #days>{{ daysOfMonthRemaining }}</template>
        </gl-sprintf>
      </span>
    </p>
    <div class="gl-flex gl-flex-row gl-justify-between">
      <span class="gl-text-size-h2 gl-font-bold" data-testid="total-units-used">
        {{ numberToMetricPrefix(totalUnitsUsed) }}
      </span>
      <span class="gl-text-size-h2 gl-font-bold gl-text-gray-500" data-testid="total-units">
        {{ $options.totalUnitsSeparator }}
        {{ numberToMetricPrefix(totalUnits) }}
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

        <span data-testid="pool-units-remaining">
          <gl-sprintf
            :message="
              n__(
                'UsageBilling|%{poolTokensRemaining} pool unit remaining',
                'UsageBilling|%{poolTokensRemaining} pool units remaining',
                usageRemaining,
              )
            "
          >
            <template #poolTokensRemaining>{{ numberToMetricPrefix(usageRemaining) }}</template>
          </gl-sprintf>
        </span>
      </div>
      <div class="gl-flex gl-flex-row gl-justify-between" data-testid="current-overage">
        <span>{{ s__('UsageBilling|Current overage') }}</span>
        <span>{{ currentOverage }}</span>
      </div>
    </div>
  </gl-card>
</template>
