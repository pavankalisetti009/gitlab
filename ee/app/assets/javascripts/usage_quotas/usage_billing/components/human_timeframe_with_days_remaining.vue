<script>
import { GlSprintf } from '@gitlab/ui';
import { getDayDifference } from '~/lib/utils/datetime/date_calculation_utility';
import { newDate } from '~/lib/utils/datetime_utility';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';

export default {
  name: 'HumanTimeframeWithDaysRemaining',
  components: {
    GlSprintf,
    HumanTimeframe,
  },
  props: {
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
    daysOfMonthRemaining() {
      const today = new Date();
      const endDate = newDate(this.monthEndDate);
      const diffDays = getDayDifference(today, endDate);

      return Math.max(0, diffDays);
    },
  },
};
</script>
<template>
  <span class="gl-text-gray-600">
    <gl-sprintf
      :message="
        n__(
          'UsageBilling|%{timeframe} - %{days} day remaining',
          'UsageBilling|%{timeframe} - %{days} days remaining',
          daysOfMonthRemaining,
        )
      "
    >
      <template #timeframe>
        <human-timeframe :from="monthStartDate" :till="monthEndDate" />
      </template>
      <template #days>{{ daysOfMonthRemaining }}</template>
    </gl-sprintf>
  </span>
</template>
