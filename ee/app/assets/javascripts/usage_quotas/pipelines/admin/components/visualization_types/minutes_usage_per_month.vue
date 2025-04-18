<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/dist/charts';
import { __, s__ } from '~/locale';

const X_AXIS_CATEGORY = 'category';

export default {
  components: {
    GlAreaChart,
    GlTab,
    GlTabs,
  },
  props: {
    usageData: {
      type: Array,
      required: true,
    },
  },
  computed: {
    formattedData() {
      return [
        {
          data: this.sortedUsageData,
          name: s__('UsageQuota|Hosted runner pipeline duration by month'),
        },
      ];
    },
    sortedUsageData() {
      return this.usageData
        .slice()
        .sort((a, b) => new Date(a.billingMonthIso8601) - new Date(b.billingMonthIso8601))
        .map((el) => [el.billingMonth, el.computeMinutes]);
    },
  },
  chartOptions: {
    xAxis: {
      name: __('Month'),
      type: X_AXIS_CATEGORY,
    },
    yAxis: {
      name: __('Compute minutes'),
      axisLabel: {
        formatter: (val) => val,
      },
    },
  },
};
</script>
<template>
  <gl-tabs>
    <gl-tab :title="s__('UsageQuota|Compute usage')">
      <gl-area-chart :data="formattedData" :option="$options.chartOptions" responsive :width="0" />
    </gl-tab>
  </gl-tabs>
</template>
