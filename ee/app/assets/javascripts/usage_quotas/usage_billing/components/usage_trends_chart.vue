<script>
import { GlCard } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { s__, __ } from '~/locale';
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
    monthlyCommitmentDailyUsage: {
      type: Array,
      required: true,
    },
    monthlyWaiverDailyUsage: {
      type: Array,
      required: true,
    },
    overageDailyUsage: {
      type: Array,
      required: true,
    },
  },
  computed: {
    monthlyCommitmentData() {
      return this.arrangeData(this.monthlyCommitmentDailyUsage);
    },
    monthlyWaiverData() {
      return this.arrangeData(this.monthlyWaiverDailyUsage);
    },
    overage() {
      return this.arrangeData(this.overageDailyUsage);
    },
    chartData() {
      return [
        {
          name: s__('UsageBilling|Monthly commitment'),
          stack: 'daily',
          data: this.monthlyCommitmentData,
        },
        {
          name: s__('UsageBilling|Monthly waiver'),
          stack: 'daily',
          data: this.monthlyWaiverData,
        },
        {
          name: s__('UsageBilling|On-demand'),
          stack: 'daily',
          data: this.overage,
        },
      ];
    },
  },
  methods: {
    /**
     * @param { {creditsUsed: number, date: string}[] } dailyUsage
     */
    arrangeData(dailyUsage) {
      return dailyUsage.map(({ date, creditsUsed }) => [date, creditsUsed]);
    },
  },
  chartOptions: {
    xAxis: { name: __('Date'), type: 'category' },
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

      <gl-area-chart :data="chartData" :option="$options.chartOptions" width="auto" />
    </gl-card>
  </section>
</template>
