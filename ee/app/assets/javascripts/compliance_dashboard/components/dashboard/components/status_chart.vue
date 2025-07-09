<script>
import { GlBarChart } from '@gitlab/ui/dist/charts';
import { s__ } from '~/locale';
import { getColors } from '../utils/chart';

export default {
  components: {
    GlBarChart,
  },
  props: {
    colorScheme: {
      type: String,
      required: true,
    },
    data: {
      type: Object,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    xAxisTitle: {
      type: String,
      required: true,
    },
  },
  computed: {
    chartData() {
      return {
        items: [
          {
            value: [this.data.passed, this.$options.legend.passed],
            itemStyle: { color: this.colors.blueDataColor },
          },
          {
            value: [this.data.pending, this.$options.legend.pending],
            itemStyle: { color: this.colors.orangeDataColor },
          },
          {
            value: [this.data.failed, this.$options.legend.failed],
            itemStyle: { color: this.colors.magentaDataColor },
          },
        ],
      };
    },
    chartOption() {
      return {
        grid: {
          left: '15%',
        },
        yAxis: {
          nameGap: 60,
        },
      };
    },
    colors() {
      return getColors(this.colorScheme);
    },
  },
  methods: {
    handleChartClick() {
      this.$router.push({ name: this.path });
    },
  },
  legend: {
    passed: s__('Compliance report|Passed'),
    failed: s__('Compliance report|Failed'),
    pending: s__('Compliance report|Pending'),
  },
};
</script>

<template>
  <gl-bar-chart
    :x-axis-title="xAxisTitle"
    :y-axis-title="s__('ComplianceReport|Count')"
    height="auto"
    :data="chartData"
    :option="chartOption"
    @chartItemClicked="handleChartClick"
  />
</template>
