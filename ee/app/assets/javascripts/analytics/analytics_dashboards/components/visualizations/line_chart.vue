<script>
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import merge from 'lodash/merge';

import {
  formatVisualizationTooltipTitle,
  formatVisualizationValue,
  humanizeChartTooltipValue,
  removeNullSeries,
} from './utils';

export default {
  name: 'LineChart',
  components: {
    GlLineChart,
    GlChartSeriesLabel,
  },
  props: {
    data: {
      type: Array,
      required: false,
      default: () => [],
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    includeLegendAvgMax() {
      return Boolean(this.options.includeLegendAvgMax);
    },
    fullOptions() {
      return merge({ yAxis: { min: 0 } }, this.options);
    },
    chartTooltipTitleFormatter() {
      return this.options?.chartTooltip?.titleFormatter;
    },
  },
  methods: {
    formatVisualizationTooltipTitle,
    formatChartTooltipValue(value) {
      const { chartTooltip: { valueUnit: unit } = {} } = this.options;

      if (unit) {
        return humanizeChartTooltipValue({ unit, value });
      }

      return formatVisualizationValue(value);
    },
    tooltipData(params) {
      if (!params) return [];

      return removeNullSeries(params.seriesData);
    },
  },
};
</script>

<template>
  <gl-line-chart
    :data="data"
    :option="fullOptions"
    :include-legend-avg-max="includeLegendAvgMax"
    height="auto"
    responsive
    class="gl-overflow-hidden"
    data-testid="dashboard-visualization-line-chart"
  >
    <template #tooltip-title="{ title, params }">
      {{ formatVisualizationTooltipTitle(title, params, chartTooltipTitleFormatter) }}</template
    >
    <template #tooltip-content="{ params }">
      <div
        v-for="{ seriesId, seriesName, color, value } in tooltipData(params)"
        :key="seriesId"
        data-testid="chart-tooltip-item"
        class="gl-flex gl-min-w-30 gl-justify-between gl-leading-24"
      >
        <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">{{
          seriesName
        }}</gl-chart-series-label>
        <span class="gl-font-bold" data-testid="chart-tooltip-value">{{
          formatChartTooltipValue(value[1])
        }}</span>
      </div>
    </template>
  </gl-line-chart>
</template>
