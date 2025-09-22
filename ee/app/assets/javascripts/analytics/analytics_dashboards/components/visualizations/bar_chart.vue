<script>
import { GlBarChart } from '@gitlab/ui/src/charts';
import { isNil } from 'lodash';
import { humanizeChartTooltipValue } from './utils';

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
  methods: {
    formatTooltipTitle(title, params) {
      const { chartTooltip: { titleFormatter } = {} } = this.options;
      const yAxisValue = params?.seriesData?.at(0)?.value?.at(1);

      if (isNil(yAxisValue)) return '';

      if (titleFormatter) return titleFormatter(yAxisValue);

      return title;
    },
    formatTooltipValue(value) {
      const { chartTooltip: { valueUnit: unit } = {} } = this.options;

      return humanizeChartTooltipValue({ unit, value });
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
    :presentation="options.presentation"
    height="auto"
    responsive
    tabindex="0"
  >
    <template #tooltip-title="{ title, params }">{{ formatTooltipTitle(title, params) }}</template>
    <template #tooltip-value="{ value }">{{ formatTooltipValue(value) }}</template>
  </gl-bar-chart>
</template>
