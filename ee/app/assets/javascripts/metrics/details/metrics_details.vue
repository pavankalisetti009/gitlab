<script>
import { GlLoadingIcon, GlEmptyState, GlSprintf, GlButton } from '@gitlab/ui';
import EMPTY_CHART_SVG from '@gitlab/svgs/dist/illustrations/chart-empty-state.svg?url';
import { uniqueId } from 'lodash';
import { s__, __ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  prepareTokens,
  processFilters as processFilteredSearchFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import axios from '~/lib/utils/axios_utils';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { TIME_RANGE_OPTIONS } from '~/observability/constants';
import { InternalEvents } from '~/tracking';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import RelatedIssue from '~/observability/components/observability_related_issues.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { ingestedAtTimeAgo } from '../utils';
import { VIEW_METRICS_DETAILS_PAGE } from '../events';
import MetricsLineChart from './metrics_line_chart.vue';
import FilteredSearch from './filter_bar/metrics_filtered_search.vue';
import { filterObjToQuery, queryToFilterObj } from './filters';
import MetricsHeatMap from './metrics_heatmap.vue';
import { createIssueUrlWithMetricDetails, isHistogram } from './utils';
import RelatedIssuesProvider from './related_issues/related_issues_provider.vue';
import RelatedTraces from './related_traces.vue';

const VISUAL_HEATMAP = 'heatmap';

export default {
  i18n: {
    error: s__(
      'ObservabilityMetrics|Error: Failed to load metrics details. Try reloading the page.',
    ),
    metricType: s__('ObservabilityMetrics|Type'),
    lastIngested: s__('ObservabilityMetrics|Last ingested'),
    cancelledWarning: s__('ObservabilityMetrics|Metrics search has been cancelled.'),
    createIssueTitle: __('Create issue'),
  },
  components: {
    GlSprintf,
    GlLoadingIcon,
    MetricsLineChart,
    GlEmptyState,
    FilteredSearch,
    UrlSync,
    MetricsHeatMap,
    PageHeading,
    GlButton,
    RelatedIssuesProvider,
    RelatedIssue,
    RelatedIssuesBadge,
    RelatedTraces,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
    metricId: {
      required: true,
      type: String,
    },
    metricType: {
      required: true,
      type: String,
    },
    metricsIndexUrl: {
      required: true,
      type: String,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    projectFullPath: {
      required: true,
      type: String,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      metricData: null,
      searchMetadata: null,
      filters: queryToFilterObj(window.location.search),
      apiAbortController: null,
      loading: false,
      queryCancelled: false,
      selectedDatapoints: [],
    };
  },
  computed: {
    header() {
      return {
        title: this.metricId,
        type: this.metricType,
        lastIngested: ingestedAtTimeAgo(this.searchMetadata?.last_ingested_at),
        description: this.searchMetadata?.description,
      };
    },
    attributeFiltersValue() {
      // only attributes are used by the filtered_search component, so only those needs processing
      return prepareTokens(this.filters.attributes);
    },
    query() {
      return filterObjToQuery(this.filters);
    },
    noDataTimeText() {
      const selectedValue = this.filters?.dateRange?.value;
      if (selectedValue) {
        const option = TIME_RANGE_OPTIONS.find((timeOption) => timeOption.value === selectedValue);
        if (option) {
          return `(${option.title.toLowerCase()})`;
        }
      }
      return '';
    },
    shouldShowLoadingIcon() {
      // only show the spinner on the first load or when there is no metric
      return this.loading && this.noMetric;
    },
    noMetric() {
      return !this.metricData || !this.metricData.length;
    },
    createIssueUrlWithQuery() {
      return createIssueUrlWithMetricDetails({
        metricName: this.metricId,
        metricType: this.metricType,
        filters: this.filters,
        createIssueUrl: this.createIssueUrl,
      });
    },
  },
  created() {
    this.validateAndFetch();
  },
  mounted() {
    this.trackEvent(VIEW_METRICS_DETAILS_PAGE);
  },
  methods: {
    async validateAndFetch() {
      if (!this.metricId || !this.metricType) {
        createAlert({
          message: this.$options.i18n.error,
        });
        return;
      }
      this.loading = true;
      try {
        await Promise.all([this.fetchMetricSearchMetadata(), this.fetchMetricData()]);
      } catch (e) {
        createAlert({
          message: this.$options.i18n.error,
        });
      } finally {
        this.loading = false;
      }
    },
    async fetchMetricSearchMetadata() {
      try {
        this.searchMetadata = await this.observabilityClient.fetchMetricSearchMetadata(
          this.metricId,
          this.metricType,
        );
      } catch (e) {
        createAlert({
          message: this.$options.i18n.error,
        });
      }
    },
    async fetchMetricData() {
      this.queryCancelled = false;
      this.loading = true;
      try {
        this.apiAbortController = new AbortController();
        const metricData = await this.observabilityClient.fetchMetric(
          this.metricId,
          this.metricType,
          {
            filters: this.filters,
            abortController: this.apiAbortController,
            ...(isHistogram(this.metricType) && { visual: VISUAL_HEATMAP }),
          },
        );
        // gl-chart is merging data by default. As I workaround we can
        // set the data to [] first, as explained in https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2577
        this.metricData = [];
        this.$nextTick(() => {
          this.metricData = metricData;
        });
      } catch (e) {
        if (axios.isCancel(e)) {
          this.cancel();
        } else {
          createAlert({
            message: this.$options.i18n.error,
          });
        }
      } finally {
        this.apiAbortController = null;
        this.loading = false;
      }
    },
    goToMetricsIndex() {
      visitUrl(this.metricsIndexUrl);
    },
    onSubmit({ attributes, dateRange, groupBy }) {
      this.filters = {
        // only attributes are used by the filtered_search component, so only those needs processing
        attributes: processFilteredSearchFilters(attributes),
        dateRange,
        groupBy,
      };
      this.fetchMetricData();
    },
    onCancel() {
      this.apiAbortController?.abort();
    },
    cancel() {
      this.$toast.show(this.$options.i18n.cancelledWarning, {
        variant: 'danger',
      });
      this.queryCancelled = true;
    },
    getChartComponent() {
      return isHistogram(this.metricType) ? MetricsHeatMap : MetricsLineChart;
    },
    onChartSelected(datapoints) {
      this.selectedDatapoints = datapoints;
    },
  },
  EMPTY_CHART_SVG,
  relatedIssuesHelpPath: helpPagePath('/operations/metrics', {
    anchor: 'create-an-issue-for-a-metric',
  }),
  relatedIssuesId: uniqueId('related-issues-'),
};
</script>

<template>
  <related-issues-provider
    :project-full-path="projectFullPath"
    :metric-type="metricType"
    :metric-name="metricId"
  >
    <template #default="{ issues, loading: fetchingIssues, error }">
      <div v-if="shouldShowLoadingIcon" class="gl-py-5">
        <gl-loading-icon size="lg" />
      </div>

      <div v-else data-testid="metric-details" class="gl-mx-6">
        <url-sync :query="query" />

        <header>
          <page-heading :heading="header.title">
            <template #actions>
              <related-issues-badge
                :issues-total="issues.length"
                :loading="fetchingIssues"
                :error="error"
                :anchor-id="$options.relatedIssuesId"
              />
              <gl-button category="primary" variant="confirm" :href="createIssueUrlWithQuery">
                {{ $options.i18n.createIssueTitle }}
              </gl-button>
            </template>

            <template #description>
              <p class="gl-my-0 gl-text-primary">
                <strong>{{ $options.i18n.metricType }}:&nbsp;</strong>{{ header.type }}
              </p>
              <p class="gl-my-0 gl-text-primary">
                <strong>{{ $options.i18n.lastIngested }}:&nbsp;</strong>{{ header.lastIngested }}
              </p>
              <p class="gl-my-0 gl-text-primary">
                {{ header.description }}
              </p>
            </template>
          </page-heading>
        </header>

        <div class="gl-my-6">
          <filtered-search
            v-if="searchMetadata"
            :loading="loading"
            :search-metadata="searchMetadata"
            :attribute-filters="attributeFiltersValue"
            :date-range-filter="filters.dateRange"
            :group-by-filter="filters.groupBy"
            @submit="onSubmit"
            @cancel="onCancel"
          />

          <div v-if="metricData && metricData.length">
            <component
              :is="getChartComponent()"
              :metric-data="metricData"
              :loading="loading"
              :cancelled="queryCancelled"
              data-testid="metric-chart"
              class="gl-mb-5"
              @selected="onChartSelected"
            />

            <related-traces
              class="gl-mb-5 gl-ml-11"
              :data-points="selectedDatapoints"
              :tracing-index-url="tracingIndexUrl"
            />
          </div>

          <gl-empty-state v-else :svg-path="$options.EMPTY_CHART_SVG">
            <template #title>
              <p class="gl-my-0 gl-text-lg">
                <gl-sprintf
                  :message="
                    s__('ObservabilityMetrics|No data found for the selected time range %{time}')
                  "
                >
                  <template #time>
                    {{ noDataTimeText }}
                  </template>
                </gl-sprintf>
              </p>

              <p class="gl-font-md gl-my-1">
                <strong>{{ $options.i18n.lastIngested }}:&nbsp;</strong>{{ header.lastIngested }}
              </p>
            </template>
          </gl-empty-state>

          <related-issue
            :id="$options.relatedIssuesId"
            :issues="issues"
            :fetching-issues="fetchingIssues"
            :error="error"
            :help-path="$options.relatedIssuesHelpPath"
          />
        </div>
      </div>
    </template>
  </related-issues-provider>
</template>
