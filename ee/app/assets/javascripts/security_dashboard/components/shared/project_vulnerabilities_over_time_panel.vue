<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_project_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';
import { DASHBOARD_LOOKBACK_DAYS } from 'ee/security_dashboard/constants';

export default {
  name: 'ProjectVulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
  },
  inject: ['projectFullPath'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    vulnerabilitiesOverTime: {
      query: getVulnerabilitiesOverTime,
      variables() {
        const lookbackDate = getDateInPast(new Date(), DASHBOARD_LOOKBACK_DAYS);
        const startDate = formatDate(lookbackDate, 'isoDate');
        const endDate = formatDate(new Date(), 'isoDate');

        return {
          fullPath: this.projectFullPath,
          startDate,
          endDate,
          reportType: this.filters.reportType,
        };
      },
      update(data) {
        const rawData = data.project?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
        return formatVulnerabilitiesOverTimeData(rawData);
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
    <template #body>
      <vulnerabilities-over-time-chart
        v-if="!fetchError && hasChartData"
        class="gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="vulnerabilitiesOverTime"
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
