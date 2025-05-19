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
          if (typeof name === 'string' && Array.isArray(data)) {
            return true;
          }

          return false;
        });
      },
    },
  },
  computed: {
    chartStartDate() {
      if (!this.chartSeries?.length || !this.chartSeries[0]?.data?.length) {
        return null;
      }

      const firstSeriesEntry = this.chartSeries[0].data[0];
      if (!firstSeriesEntry) {
        return null;
      }

      const firstDay = firstSeriesEntry[0];
      return firstDay;
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
