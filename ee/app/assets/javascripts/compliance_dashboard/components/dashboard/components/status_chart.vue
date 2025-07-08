<script>
import { GlBarChart } from '@gitlab/ui/dist/charts';
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
    legend: {
      type: Object,
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
            value: [this.data.passed, this.legend.passed],
            itemStyle: { color: this.colors.blueDataColor },
          },
          {
            value: [this.data.pending, this.legend.pending],
            itemStyle: { color: this.colors.orangeDataColor },
          },
          {
            value: [this.data.failed, this.legend.failed],
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
};
</script>

<template>
  <gl-bar-chart
    :x-axis-title="xAxisTitle"
    y-axis-title="Count"
    height="auto"
    :data="chartData"
    :option="chartOption"
    @chartItemClicked="handleChartClick"
  />
</template>
