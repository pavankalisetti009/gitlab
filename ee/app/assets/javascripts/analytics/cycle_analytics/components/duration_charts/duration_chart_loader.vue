<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { getDurationChart } from 'ee/api/analytics_api';
import { transformFilters } from 'ee/analytics/shared/utils';
import { DEFAULT_RENAMED_FILTER_KEYS } from 'ee/analytics/shared/constants';
import {
  getDurationOverviewChartData,
  getDurationChartData,
  checkForDataError,
  getValueStreamGraphQLId,
  getValueStreamStageGraphQLId,
} from '../../utils';
import getValueStreamStageMetricsQuery from '../../graphql/queries/get_value_stream_stage_metrics.query.graphql';
import OverviewChart from './overview_chart.vue';
import StageChart from './stage_chart.vue';
import StageScatterChart from './stage_scatter_chart.vue';

export default {
  name: 'DurationChartLoader',
  components: {
    ChartSkeletonLoader,
    GlAlert,
    OverviewChart,
    StageChart,
    StageScatterChart,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      isLoading: false,
      durationData: [],
      errorMessage: '',
      stageMetricsItems: [],
      stageMetricsItemsPageInfo: {},
    };
  },
  computed: {
    ...mapState(['selectedStage', 'createdAfter', 'createdBefore', 'namespace']),
    ...mapGetters([
      'isOverviewStageSelected',
      'activeStages',
      'cycleAnalyticsRequestParams',
      'namespaceRestApiRequestPath',
      'currentValueStreamId',
      'isProjectNamespace',
    ]),
    hasPlottableData() {
      return this.durationData.some(({ data }) => data.length);
    },
    overviewChartPlottableData() {
      return this.hasPlottableData ? getDurationOverviewChartData(this.durationData) : [];
    },
    stageChartPlottableData() {
      const { createdAfter, createdBefore, durationData, selectedStage } = this;
      const stageDurationData = durationData.find((stage) => stage.id === selectedStage.id);

      return stageDurationData?.data?.length
        ? getDurationChartData([stageDurationData], createdAfter, createdBefore)
        : [];
    },
    stageScatterChartEnabled() {
      return this.glFeatures?.vsaStageTimeScatterChart;
    },
    stageScatterChartPlottableData() {
      return this.stageMetricsItems.map(({ durationInMilliseconds, endEventTimestamp }) => [
        endEventTimestamp,
        durationInMilliseconds,
      ]);
    },
    stageScatterChartIssuableType() {
      const [stageMetricItem] = this.stageMetricsItems;
      const { record: { __typename } = {} } = stageMetricItem ?? {};

      return __typename;
    },
    shouldFetchScatterChartData() {
      return this.stageScatterChartEnabled && !this.isOverviewStageSelected;
    },
  },
  watch: {
    selectedStage() {
      this.fetchChartData();
    },
  },
  created() {
    this.fetchChartData();
  },
  methods: {
    async fetchChartData() {
      this.isLoading = true;
      this.errorMessage = '';

      if (this.shouldFetchScatterChartData) {
        // Reset scatter chart data
        this.stageMetricsItems = [];
        this.stageMetricsItemsPageInfo = {};

        await this.fetchScatterChartData();
      } else {
        await this.fetchDurationData();
      }

      this.isLoading = false;
    },
    async fetchDurationData() {
      await Promise.all(
        this.activeStages.map(({ id, name }) => {
          return getDurationChart({
            stageId: id,
            namespacePath: this.namespaceRestApiRequestPath,
            valueStreamId: this.currentValueStreamId,
            params: this.cycleAnalyticsRequestParams,
          })
            .then(checkForDataError)
            .then(({ data }) => ({ id, name, selected: true, data }));
        }),
      )
        .then((data) => {
          this.durationData = data;
        })
        .catch((error) => {
          this.durationData = [];
          this.errorMessage = error.message;
          Sentry.captureException(error);
        });
    },
    async fetchScatterChartData(endCursor) {
      const filters = transformFilters({
        filters: this.cycleAnalyticsRequestParams,
        renamedKeys: {
          labelName: 'labelNames',
          'not[labelName]': 'not[labelNames]',
          ...DEFAULT_RENAMED_FILTER_KEYS,
        },
        dropKeys: ['created_after', 'created_before', 'project_ids'],
      });

      try {
        const { data } = await this.$apollo.query({
          query: getValueStreamStageMetricsQuery,
          variables: {
            fullPath: this.namespace.path,
            isProject: this.isProjectNamespace,
            valueStreamId: getValueStreamGraphQLId(this.currentValueStreamId),
            stageId: getValueStreamStageGraphQLId(this.selectedStage.id),
            startDate: this.createdAfter,
            endDate: this.createdBefore,
            endCursor,
            ...filters,
          },
        });

        const namespaceType = this.isProjectNamespace ? 'project' : 'group';
        const { stages } = data?.[namespaceType]?.valueStreams?.nodes?.at(0) || {};
        const { edges = [], pageInfo } = stages?.at(0)?.metrics?.items || {};

        this.stageMetricsItems = [...this.stageMetricsItems, ...edges.map(({ node }) => node)];
        this.stageMetricsItemsPageInfo = pageInfo;

        // Lazy load additional pages
        if (pageInfo?.hasNextPage) {
          this.isLoading = false;
          await this.fetchScatterChartData(pageInfo.endCursor);
        }
      } catch (error) {
        this.errorMessage = error.message;
        Sentry.captureException(error);
      }
    },
  },
};
</script>
<template>
  <chart-skeleton-loader v-if="isLoading" size="md" class="gl-my-4 gl-py-4" />
  <gl-alert
    v-else-if="errorMessage"
    :title="s__('CycleAnalytics|Failed to load chart data.')"
    variant="danger"
    :dismissible="false"
    class="gl-mt-3"
  >
    {{ errorMessage }}
  </gl-alert>
  <overview-chart
    v-else-if="isOverviewStageSelected"
    :plottable-data="overviewChartPlottableData"
  />
  <stage-scatter-chart
    v-else-if="stageScatterChartEnabled"
    :stage-title="selectedStage.title"
    :issuable-type="stageScatterChartIssuableType"
    :plottable-data="stageScatterChartPlottableData"
    :start-date="createdAfter"
    :end-date="createdBefore"
  />
  <stage-chart
    v-else
    :stage-title="selectedStage.title"
    :plottable-data="stageChartPlottableData"
  />
</template>
