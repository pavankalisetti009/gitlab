<script>
import { GlCard } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { minBy } from 'lodash';
import {
  newDate,
  getDatesInRange,
  nDaysBefore,
} from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';
import { s__ } from '~/locale';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';

export default {
  name: 'UsageTrendsChart',
  components: {
    GlCard,
    GlAreaChart,
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
    monthlyCommitmentIsAvailable: {
      type: Boolean,
      required: true,
    },
    monthlyCommitmentDailyUsage: {
      type: Array,
      required: true,
    },
    monthlyWaiverIsAvailable: {
      type: Boolean,
      required: true,
    },
    monthlyWaiverDailyUsage: {
      type: Array,
      required: true,
    },
    overageIsAllowed: {
      type: Boolean,
      required: true,
    },
    overageDailyUsage: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      today: toISODateFormat(new Date()),
    };
  },
  computed: {
    monthDates() {
      const startDate = newDate(this.monthStartDate);
      const endDate = newDate(this.monthEndDate);

      // NOTE: getDatesInRange or the way we call it might have issues
      // Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/583673
      return getDatesInRange(startDate, endDate, toISODateFormat);
    },
    monthlyCommitmentData() {
      return this.accumulateValues(this.monthlyCommitmentDailyUsage);
    },
    monthlyWaiverData() {
      return this.accumulateValues(this.monthlyWaiverDailyUsage);
    },
    overageData() {
      return this.accumulateValues(this.overageDailyUsage);
    },
    chartData() {
      return [
        this.monthlyCommitmentIsAvailable && {
          name: s__('UsageBilling|Monthly commitment'),
          stack: 'daily',
          data: this.monthlyCommitmentData,
        },
        this.monthlyWaiverIsAvailable && {
          name: s__('UsageBilling|Monthly waiver'),
          stack: 'daily',
          data: this.monthlyWaiverData,
        },
        this.overageIsAllowed && {
          name: s__('UsageBilling|On-demand'),
          stack: 'daily',
          data: this.overageData,
        },
      ].filter(Boolean);
    },
  },
  methods: {
    /** @param { { date: string, creditsUsed: number }[] } data */
    accumulateValues(data) {
      if (!data.length) return [];

      // Ensuring to pick the first date, even if data is not properly ordered
      const firstEventDate = minBy(data, (d) => d.date).date;
      const dateOneDayBeforeFirstEvent = toISODateFormat(nDaysBefore(newDate(firstEventDate), 1));

      // Look-up map for faster access
      const dailyUsageMap = data.reduce((acc, { date, creditsUsed }) => {
        acc[date] = creditsUsed;
        return acc;
      }, {});

      // Walk through dates of the month and accumulate usage data.
      let accumulatedCreditsUsed = 0;
      const accumulatedData = [];

      for (const date of this.monthDates) {
        if (date === dateOneDayBeforeFirstEvent) {
          // Add 0 to the day before the first event, so that the chart doesn't start abruptly.
          // If there is usage on the first day of the month, it should start abruptly.
          accumulatedData.push([date, 0]);
        } else if (date < firstEventDate || date > this.today) {
          // Clear the chart before first usage and after `today`
          accumulatedData.push([date, null]);
        } else {
          // Accumulate usage in active period (`dailyUsageMap[date] || 0` handles no usage plateu)
          accumulatedCreditsUsed += dailyUsageMap[date] || 0;
          accumulatedData.push([date, accumulatedCreditsUsed]);
        }
      }

      return accumulatedData;
    },
  },
  chartOptions: {
    xAxis: { name: s__('UsageBilling|Date'), type: 'category' },
    yAxis: { name: s__('UsageBilling|Credits') },
  },
};
</script>
<template>
  <section>
    <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-p-5">
      <header class="gl-mb-3">
        <h2 class="gl-heading-scale-300 gl-mb-1 gl-font-heading">
          {{ s__('UsageBilling|GitLab Credits usage') }}
        </h2>

        <human-timeframe
          class="gl-text-sm gl-text-subtle"
          :from="monthStartDate"
          :till="monthEndDate"
        />
      </header>

      <gl-area-chart
        :data="chartData"
        :option="$options.chartOptions"
        width="auto"
        :include-legend-avg-max="false"
      />
    </gl-card>
  </section>
</template>
