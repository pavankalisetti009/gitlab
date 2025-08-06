<script>
import { GlBarChart } from '@gitlab/ui/dist/charts';

export default {
  name: 'BarChart',
  components: {
    GlBarChart,
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
};
</script>

<template>
  <gl-bar-chart
    :data="data"
    :option="options"
    :x-axis-title="options.xAxis.name"
    :y-axis-title="options.yAxis.name"
    :x-axis-type="options.xAxis.type"
    height="auto"
    responsive
  />
</template>
