<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  TYPENAME_PROJECT,
  TYPENAME_VALUE_STREAM,
  TYPENAME_VALUE_STREAM_STAGE,
} from '~/graphql_shared/constants';
import { transformFilters } from 'ee/analytics/shared/utils';
import { DEFAULT_RENAMED_FILTER_KEYS } from 'ee/analytics/shared/constants';
import { parseAverageDurationsQueryResponse } from '../../utils';
import getValueStreamStageMetricsQuery from '../../graphql/queries/get_value_stream_stage_metrics.query.graphql';
import getValueStreamStageAverageDurations from '../../graphql/queries/get_value_stream_stage_average_durations.query.graphql';
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
      averageDurations: null,
      errorMessage: '',
      isLoading: false,
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
      'currentValueStreamId',
      'isProjectNamespace',
    ]),
    stageScatterChartEnabled() {
      return this.glFeatures?.vsaStageTimeScatterChart;
    },
    stageScatterChartIssuableType() {
      const [stageMetricItem] = this.stageMetricsItems;
      const { record: { __typename } = {} } = stageMetricItem ?? {};

      return __typename;
    },
    shouldFetchScatterChartData() {
      return this.stageScatterChartEnabled && !this.isOverviewStageSelected;
    },
    activeStageIds() {
      return this.activeStages.map(({ id }) => id);
    },
    plottableData() {
      if (this.isOverviewStageSelected) {
        return this.averageDurations;
      }

      if (this.stageScatterChartEnabled) {
        return this.stageMetricsItems.map(({ durationInMilliseconds, endEventTimestamp }) => [
          endEventTimestamp,
          durationInMilliseconds,
        ]);
      }

      return this.averageDurations.find(({ id }) => id === this.selectedStage.id)?.data;
    },
    gqlVariables() {
      const filters = transformFilters({
        filters: this.cycleAnalyticsRequestParams,
        renamedKeys: {
          labelName: 'labelNames',
          'not[labelName]': 'not[labelNames]',
          ...DEFAULT_RENAMED_FILTER_KEYS,
        },
        dropKeys: ['created_after', 'created_before'],
      });

      if (filters.projectIds) {
        filters.projectIds = filters.projectIds.map((id) =>
          convertToGraphQLId(TYPENAME_PROJECT, id),
        );
      }

      return {
        fullPath: this.namespace.path,
        isProject: this.isProjectNamespace,
        valueStreamId: convertToGraphQLId(TYPENAME_VALUE_STREAM, this.currentValueStreamId),
        startDate: this.createdAfter,
        endDate: this.createdBefore,
        ...filters,
      };
    },
  },
  watch: {
    selectedStage() {
      if (this.stageScatterChartEnabled) {
        if (this.isOverviewStageSelected) {
          this.fetchAllChartData();
        } else {
          this.fetchScatterChartData();
        }
      }
    },
  },
  created() {
    if (this.shouldFetchScatterChartData) {
      this.fetchScatterChartData();
    } else {
      this.fetchAllChartData();
    }
  },
  methods: {
    async fetchAllChartData() {
      try {
        this.isLoading = true;

        const result = await Promise.all(
          this.activeStageIds.map((stageId) =>
            this.$apollo.query({
              query: getValueStreamStageAverageDurations,
              variables: {
                ...this.gqlVariables,
                stageId: convertToGraphQLId(TYPENAME_VALUE_STREAM_STAGE, stageId),
              },
            }),
          ),
        );
        const stageData = result.map(
          ({ data }) =>
            data[this.isProjectNamespace ? 'project' : 'group'].valueStreams.nodes[0].stages[0],
        );

        this.averageDurations = parseAverageDurationsQueryResponse(
          this.createdAfter,
          this.createdBefore,
          stageData,
        );
      } catch (error) {
        this.handleError(error);
        this.averageDurations = null;
      } finally {
        this.isLoading = false;
      }
    },
    async fetchScatterChartData(endCursor) {
      if (!this.shouldFetchScatterChartData) return;

      // Reset chart data for the first request (when end cursor is undefined)
      if (!endCursor) {
        this.stageMetricsItems = [];
        this.stageMetricsItemsPageInfo = {};

        this.errorMessage = '';
        this.isLoading = true;
      }

      try {
        const { data } = await this.$apollo.query({
          query: getValueStreamStageMetricsQuery,
          variables: {
            ...this.gqlVariables,
            stageId: convertToGraphQLId(TYPENAME_VALUE_STREAM_STAGE, this.selectedStage.id),
            endCursor,
          },
        });

        const namespaceType = this.isProjectNamespace ? 'project' : 'group';
        const { stages } = data?.[namespaceType]?.valueStreams?.nodes?.at(0) || {};
        const { edges = [], pageInfo } = stages?.at(0)?.metrics?.items || {};

        this.stageMetricsItems = [...this.stageMetricsItems, ...edges.map(({ node }) => node)];
        this.stageMetricsItemsPageInfo = pageInfo;

        // Lazy load any additional pages
        this.isLoading = false;

        if (pageInfo?.hasNextPage) {
          await this.fetchScatterChartData(pageInfo.endCursor);
        }
      } catch (error) {
        this.isLoading = false;
        this.handleError(error);
      }
    },
    handleError(error) {
      this.errorMessage = error.message;
      Sentry.captureException(error);
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
  <overview-chart v-else-if="isOverviewStageSelected" :plottable-data="plottableData" />
  <stage-scatter-chart
    v-else-if="stageScatterChartEnabled"
    :stage-title="selectedStage.title"
    :issuable-type="stageScatterChartIssuableType"
    :plottable-data="plottableData"
    :start-date="createdAfter"
    :end-date="createdBefore"
  />
  <stage-chart v-else :stage-title="selectedStage.title" :plottable-data="plottableData" />
</template>
