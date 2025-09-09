<script>
import { GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SafeHtml from '~/vue_shared/directives/safe_html';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import {
  ALL_METRICS_QUERY_TYPE,
  DEPLOYMENT_FREQUENCY_SECONDARY_SERIES_NAME,
} from '~/analytics/shared/constants';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import { spriteIcon } from '~/lib/utils/common_utils';
import CiCdAnalyticsCharts from '~/analytics/ci_cd/components/ci_cd_analytics_charts.vue';
import { DEFAULT_SELECTED_CHART } from '~/analytics/ci_cd/components/constants';
import { PROMO_URL } from '~/constants';
import {
  DEPLOYMENT_FREQUENCY_METRIC_TYPE,
  getProjectDoraMetrics,
  getGroupDoraMetrics,
} from '../api/dora_api';
import DoraChartHeader from './dora_chart_header.vue';
import {
  allChartDefinitions,
  areaChartOptions,
  averageSeriesOptions,
  chartDescriptionText,
  chartDocumentationHref,
  LAST_WEEK,
  LAST_MONTH,
  LAST_90_DAYS,
  LAST_180_DAYS,
  CHART_TITLE,
} from './static_data/deployment_frequency';
import {
  apiDataToChartSeries,
  seriesToAverageSeries,
  extractOverviewMetricsQueryParameters,
} from './util';

const VISIBLE_METRICS = ['deploys', 'deployment-frequency', 'deployment_frequency'];
const filterFn = (data) =>
  data.filter((d) => VISIBLE_METRICS.includes(d.identifier)).map(({ links, ...rest }) => rest);

const TESTING_TERMS_URL = `${PROMO_URL}/handbook/legal/testing-agreement/`;

export default {
  name: 'DeploymentFrequencyCharts',
  components: {
    CiCdAnalyticsCharts,
    DoraChartHeader,
    ValueStreamMetrics,
    GlChartSeriesLabel,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    projectPath: {
      type: String,
      default: '',
    },
    groupPath: {
      type: String,
      default: '',
    },
    shouldRenderDoraCharts: {
      type: Boolean,
      default: false,
    },
  },
  chartInDays: {
    [LAST_WEEK]: 7,
    [LAST_MONTH]: 30,
    [LAST_90_DAYS]: 90,
    [LAST_180_DAYS]: 180,
  },
  i18n: {
    confirmationTitle: s__('DORA4Metrics|Accept testing terms of use?'),
    confirmationBtnText: s__('DORA4Metrics|Accept testing terms'),
    confirmationHtmlMessage: sprintf(
      s__('DORA4Metrics|By enabling this feature, you accept the %{url}'),
      {
        url: `<a href="${TESTING_TERMS_URL}" target="_blank" rel="noopener noreferrer nofollow">Testing Terms of Use ${spriteIcon(
          'external-link',
          's16',
        )}</a>`,
      },
      false,
    ),
  },
  data() {
    return {
      chartData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      rawApiData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      selectedChartIndex: DEFAULT_SELECTED_CHART,
      tooltipTitle: '',
      tooltipContent: [],
    };
  },
  computed: {
    charts() {
      return allChartDefinitions.map((chart) => {
        return { ...chart, data: [...this.chartData[chart.id]] };
      });
    },
    metricsRequestPath() {
      return this.projectPath ? this.projectPath : this.groupPath;
    },
  },
  async mounted() {
    const results = await Promise.allSettled(
      allChartDefinitions.map(async ({ id, requestParams, startDate, endDate }) => {
        let apiData;
        if (this.projectPath && this.groupPath) {
          throw new Error('Both projectPath and groupPath were provided');
        } else if (this.projectPath) {
          apiData = (
            await getProjectDoraMetrics(
              this.projectPath,
              DEPLOYMENT_FREQUENCY_METRIC_TYPE,
              requestParams,
            )
          ).data;
        } else if (this.groupPath) {
          apiData = (
            await getGroupDoraMetrics(
              this.groupPath,
              DEPLOYMENT_FREQUENCY_METRIC_TYPE,
              requestParams,
            )
          ).data;
        } else {
          throw new Error('Either projectPath or groupPath must be provided');
        }

        const seriesData = apiDataToChartSeries(apiData, startDate, endDate, CHART_TITLE);
        const { data } = seriesData[0];

        this.chartData[id] = [
          ...seriesData,
          {
            ...averageSeriesOptions,
            ...seriesToAverageSeries(
              data,
              sprintf(DEPLOYMENT_FREQUENCY_SECONDARY_SERIES_NAME, {
                days: this.$options.chartInDays[id],
              }),
            ),
          },
        ];

        this.rawApiData[id] = apiData;
      }),
    );

    const requestErrors = results.filter((r) => r.status === 'rejected').map((r) => r.reason);

    if (requestErrors.length) {
      createAlert({
        message: s__('DORA4Metrics|Something went wrong while getting deployment frequency data.'),
      });

      const allErrorMessages = requestErrors.join('\n');
      Sentry.captureException(
        new Error(
          `Something went wrong while getting deployment frequency data:\n${allErrorMessages}`,
        ),
      );
    }
  },
  methods: {
    onSelectChart(selectedChartIndex) {
      this.selectedChartIndex = selectedChartIndex;
    },
    getMetricsRequestParams(selectedChart) {
      return extractOverviewMetricsQueryParameters(allChartDefinitions[selectedChart]);
    },
    formatTooltipText({ value, seriesData }) {
      this.tooltipTitle = value;
      this.tooltipContent = seriesData.map(({ seriesId, seriesName, color, value: metric }) => ({
        key: seriesId,
        name: seriesName,
        color,
        value: metric[1],
      }));
    },
  },
  areaChartOptions,
  chartDescriptionText,
  chartDocumentationHref,
  filterFn,
  ALL_METRICS_QUERY_TYPE,
};
</script>
<template>
  <div data-testid="deployment-frequency-charts">
    <dora-chart-header
      :header-text="s__('DORA4Metrics|Deployment frequency')"
      :chart-description-text="$options.chartDescriptionText"
      :chart-documentation-href="$options.chartDocumentationHref"
    />
    <ci-cd-analytics-charts
      :charts="charts"
      :chart-options="$options.areaChartOptions"
      :format-tooltip-text="formatTooltipText"
      @select-chart="onSelectChart"
    >
      <template #tooltip-title>{{ tooltipTitle }}</template>
      <template #tooltip-content>
        <div
          v-for="{ key, name, color, value } in tooltipContent"
          :key="key"
          class="gl-flex gl-justify-between"
        >
          <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">
            {{ name }}
          </gl-chart-series-label>
          <div class="gl-font-bold">{{ value }}</div>
        </div>
      </template>
      <template #metrics="{ selectedChart }">
        <value-stream-metrics
          :request-path="metricsRequestPath"
          :request-params="getMetricsRequestParams(selectedChart)"
          :filter-fn="$options.filterFn"
          :query-type="$options.ALL_METRICS_QUERY_TYPE"
          :is-licensed="shouldRenderDoraCharts"
        />
      </template>
    </ci-cd-analytics-charts>
  </div>
</template>
