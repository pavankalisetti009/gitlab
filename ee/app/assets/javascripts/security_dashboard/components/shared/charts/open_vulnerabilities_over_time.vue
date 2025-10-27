<script>
import { camelCase } from 'lodash';
import { GlLink } from '@gitlab/ui';
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { constructVulnerabilitiesReportWithFiltersPath } from 'ee/security_dashboard/utils/chart_utils';
import { COLORS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';

export default {
  components: {
    GlLineChart,
    GlChartSeriesLabel,
    GlLink,
  },
  inject: ['securityVulnerabilitiesPath'],
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
    groupedBy: {
      type: String,
      required: false,
      default: '',
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    chartStartDate() {
      // Chart data structure: chartSeries = [{ name: 'Series Name', data: [[date, value], [date, value], ...] }, ...]
      // This extracts the date (first element) from the first data point of the first series
      return this.chartSeries?.[0]?.data?.[0]?.[0] ?? null;
    },
    shouldShowTooltipLink() {
      return Boolean(this.securityVulnerabilitiesPath && this.groupedBy);
    },
    chartSeriesWithColors() {
      return this.chartSeries.map((series) => {
        const color = COLORS[camelCase(series.id)];

        if (color) {
          return {
            ...series,
            itemStyle: {
              color,
            },
            lineStyle: {
              color,
            },
          };
        }

        return series;
      });
    },
    chartOptions() {
      return {
        animation: false,
        // Note: This is a workaround to remove the extra whitespace when the chart has no title
        // Once https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2199 has been fixed, this can be removed
        grid: {
          left: '10x',
          right: '10px',
          bottom: '10px',
          top: '10px',
          // Setting `containLabel` to `true` ensures the grid area is large enough to contain the labels
          containLabel: true,
        },
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
  methods: {
    vulnerabilitiesReportWithFiltersPath(seriesId) {
      return constructVulnerabilitiesReportWithFiltersPath({
        securityVulnerabilitiesPath: this.securityVulnerabilitiesPath,
        seriesId,
        filterKey: this.groupedBy,
        includeAllActivity: true,
        additionalFilters: this.filters,
      });
    },
  },
};
</script>

<template>
  <gl-line-chart
    :data="chartSeriesWithColors"
    :option="chartOptions"
    :include-legend-avg-max="false"
    :click-to-pin-tooltip="shouldShowTooltipLink"
    responsive
    height="auto"
  >
    <template #tooltip-content="{ params }">
      <div
        v-for="{ seriesName, seriesId, color, value } in params && params.seriesData"
        :key="seriesName"
        class="gl-flex gl-justify-between"
      >
        <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">
          {{ seriesName }}
        </gl-chart-series-label>
        <gl-link
          v-if="shouldShowTooltipLink"
          :href="vulnerabilitiesReportWithFiltersPath(seriesId)"
          target="_blank"
          class="gl-font-bold"
          >{{ value[1] }}</gl-link
        >
      </div>
    </template>
  </gl-line-chart>
</template>
