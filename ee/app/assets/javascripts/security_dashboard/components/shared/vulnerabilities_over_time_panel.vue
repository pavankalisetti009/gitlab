<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';

export default {
  name: 'VulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
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
      query: getVulnerabilitiesOverTime,
      variables() {
        const { projectId } = this.filters;

        return {
          ...(projectId ? { projectId } : {}),
          fullPath: this.groupFullPath,
        };
      },
      update(data) {
        const rawData = data.group?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
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
};
</script>

<template>
  <extended-dashboard-panel
    :title="__('Vulnerabilities over time')"
    :loading="$apollo.queries.vulnerabilitiesOverTime.loading"
    :show-alert-state="fetchError"
  >
    <template #body>
      <vulnerabilities-over-time-chart
        v-if="!fetchError"
        class="gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="vulnerabilitiesOverTime"
      />
      <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </extended-dashboard-panel>
</template>
