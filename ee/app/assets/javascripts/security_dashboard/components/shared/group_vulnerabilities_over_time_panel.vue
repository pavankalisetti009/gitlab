<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { fetchPolicies } from '~/lib/graphql';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_group_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_utils';
import { DASHBOARD_LOOKBACK_DAYS } from 'ee/security_dashboard/constants';
import OverTimeSeverityFilter from './over_time_severity_filter.vue';
import OverTimeGroupBy from './over_time_group_by.vue';

export default {
  name: 'GroupVulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
    OverTimeGroupBy,
    OverTimeSeverityFilter,
  },
  inject: ['groupFullPath'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    vulnerabilitiesOverTime: {
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      query: getVulnerabilitiesOverTime,
      variables() {
        const lookbackDate = getDateInPast(new Date(), DASHBOARD_LOOKBACK_DAYS);
        const startDate = formatDate(lookbackDate, 'isoDate');
        const endDate = formatDate(new Date(), 'isoDate');

        return {
          startDate,
          endDate,
          projectId: this.filters.projectId,
          reportType: this.filters.reportType,
          fullPath: this.groupFullPath,
          includeBySeverity: this.groupedBy === 'severity',
          includeByReportType: this.groupedBy === 'reportType',
          severity: this.panelLevelFilters.severity,
        };
      },
      update(data) {
        const rawData = data.group?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];

        return formatVulnerabilitiesOverTimeData(rawData, this.groupedBy);
      },
      error() {
        this.fetchError = true;
      },
    },
  },
  data() {
    return {
      vulnerabilitiesOverTime: [],
      fetchError: false,
      groupedBy: 'severity',
      panelLevelFilters: {
        severity: [],
      },
    };
  },
  computed: {
    hasChartData() {
      return this.vulnerabilitiesOverTime.length > 0;
    },
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities over time')"
    :loading="$apollo.queries.vulnerabilitiesOverTime.loading"
    :show-alert-state="fetchError"
  >
    <template #filters>
      <over-time-severity-filter v-model="panelLevelFilters.severity" />
      <over-time-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <!-- resetting the z-index to 0 to make sure the the chart's tooltip is below any filter dropdowns, etc. -->
      <vulnerabilities-over-time-chart
        v-if="!fetchError && hasChartData"
        class="gl-z-0 gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="vulnerabilitiesOverTime"
        :grouped-by="groupedBy"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="vulnerabilities-over-time-empty-state"
      >
        <template v-if="fetchError">{{ __('Something went wrong. Please try again.') }}</template>
        <template v-else>{{ __('No data available.') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
