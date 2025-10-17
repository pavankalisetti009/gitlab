<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import projectVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_over_time.query.graphql';
import groupVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_utils';
import OverTimeSeverityFilter from './over_time_severity_filter.vue';
import OverTimeGroupBy from './over_time_group_by.vue';
import OverTimePeriodSelector from './over_time_period_selector.vue';

const TIME_PERIODS = {
  THIRTY_DAYS: { key: 'thirtyDays', startDays: 30, endDays: 0 },
  SIXTY_DAYS: { key: 'sixtyDays', startDays: 60, endDays: 31 },
  NINETY_DAYS: { key: 'ninetyDays', startDays: 90, endDays: 61 },
};

const SCOPE_CONFIG = {
  project: {
    query: projectVulnerabilitiesOverTime,
    pathKey: 'projectFullPath',
    pageLevelFilters: ['reportType'],
  },
  group: {
    query: groupVulnerabilitiesOverTime,
    pathKey: 'groupFullPath',
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
    OverTimeGroupBy,
    OverTimeSeverityFilter,
    OverTimePeriodSelector,
  },
  inject: {
    projectFullPath: { default: '' },
    groupFullPath: { default: '' },
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (value) => Object.keys(SCOPE_CONFIG).includes(value),
    },
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      fetchError: false,
      groupedBy: 'severity',
      selectedTimePeriod: 30,
      isLoading: false,
      chartData: {
        thirtyDays: [],
        sixtyDays: [],
        ninetyDays: [],
      },
      panelLevelFilters: {
        severity: [],
      },
    };
  },
  computed: {
    config() {
      return SCOPE_CONFIG[this.scope];
    },
    fullPath() {
      return this[this.config.pathKey];
    },
    combinedFilters() {
      return {
        ...this.filters,
        ...this.panelLevelFilters,
      };
    },
    hasChartData() {
      return this.selectedChartData.length > 0;
    },
    selectedChartData() {
      const selectedChartData = [
        ...(this.selectedTimePeriod >= 90 ? this.chartData.ninetyDays : []),
        ...(this.selectedTimePeriod >= 60 ? this.chartData.sixtyDays : []),
        ...this.chartData.thirtyDays,
      ];

      return formatVulnerabilitiesOverTimeData(selectedChartData, this.groupedBy);
    },
    baseQueryVariables() {
      const baseVariables = {
        severity: this.panelLevelFilters.severity,
        includeBySeverity: this.groupedBy === 'severity',
        includeByReportType: this.groupedBy === 'reportType',
        fullPath: this.fullPath,
      };

      this.config.pageLevelFilters
        .filter((filterKey) => this.filters[filterKey] !== undefined)
        .forEach((filterKey) => {
          baseVariables[filterKey] = this.filters[filterKey];
        });

      return baseVariables;
    },
    selectedTimePeriods() {
      return Object.values(TIME_PERIODS).filter(
        ({ startDays }) => startDays <= this.selectedTimePeriod,
      );
    },
  },
  watch: {
    baseQueryVariables: {
      handler() {
        this.fetchChartData();
      },
      deep: true,
      immediate: true,
    },
    selectedTimePeriod() {
      this.fetchChartData();
    },
  },
  methods: {
    async fetchChartData() {
      this.isLoading = true;
      this.fetchError = false;

      try {
        // Note: we want to load each chunk sequentially for BE-performance reasons
        for await (const timePeriod of this.selectedTimePeriods) {
          await this.fetchTimeRangeData(timePeriod);
        }
      } catch (error) {
        this.fetchError = true;
      } finally {
        this.isLoading = false;
      }
    },
    async fetchTimeRangeData({ key, startDays, endDays }) {
      const startDate = formatDate(getDateInPast(new Date(), startDays), 'isoDate');
      const endDate = formatDate(getDateInPast(new Date(), endDays), 'isoDate');

      const result = await this.$apollo.query({
        query: this.config.query,
        variables: {
          ...this.baseQueryVariables,
          startDate,
          endDate,
        },
      });

      this.chartData[key] =
        result.data.namespace?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
    },
  },
  tooltip: {
    description: s__('SecurityReports|Vulnerability trends over time'),
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities over time')"
    :loading="isLoading"
    :show-alert-state="fetchError"
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <over-time-period-selector v-model="selectedTimePeriod" class="gl-ml-3 gl-mr-2" />
      <over-time-severity-filter v-model="panelLevelFilters.severity" class="gl-mr-2" />
      <over-time-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <!-- resetting the z-index to 0 to make sure the the chart's tooltip is below any filter dropdowns, etc. -->
      <vulnerabilities-over-time-chart
        v-if="!fetchError && hasChartData"
        class="gl-z-0 gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="selectedChartData"
        :grouped-by="groupedBy"
        :filters="combinedFilters"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="vulnerabilities-over-time-empty-state"
      >
        <template v-if="fetchError">{{ __('Something went wrong. Please try again.') }}</template>
        <template v-else>{{ __('No results found') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
