<script>
import { GlLineChart } from '@gitlab/ui/dist/charts';

export default {
  components: {
    GlLineChart,
  },
  props: {
    chartSeries: {
      type: Array,
      required: true,
      validator(value) {
        return value.every(({ name, data }) => {
          // Each series must have a name (string) and data (array)
          return typeof name === 'string' && Array.isArray(data);
        });
      },
    },
  },
  computed: {
    chartStartDate() {
      // Chart data structure: chartSeries = [{ name: 'Series Name', data: [[date, value], [date, value], ...] }, ...]
      // This extracts the date (first element) from the first data point of the first series
      return this.chartSeries?.[0]?.data?.[0]?.[0] ?? null;
    },
    chartOptions() {
      return {
        xAxis: {
          // Setting the `name` to `null` hides the axis name
          name: null,
          key: 'date',
          type: 'category',
        },
        yAxis: {
          name: null,
          key: 'vulnerabilities',
          type: 'value',
          minInterval: 1,
        },
        series: {
          smooth: true,
        },
        ...(this.chartStartDate !== null && {
          dataZoom: [
            {
              type: 'slider',
              startValue: this.chartStartDate,
            },
          ],
        }),
      };
    },
  },
};
</script>

<template>
  <gl-line-chart :data="chartSeries" :option="chartOptions" :include-legend-avg-max="false" />
</template>
