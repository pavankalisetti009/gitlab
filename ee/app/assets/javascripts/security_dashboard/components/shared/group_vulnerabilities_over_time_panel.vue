<script>
import { GlButton, GlButtonGroup } from '@gitlab/ui';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { fetchPolicies } from '~/lib/graphql';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_group_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';

export default {
  name: 'GroupVulnerabilitiesOverTimePanel',
  components: {
    GlButton,
    GlButtonGroup,
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
  defaultStartDate: 90,
  apollo: {
    vulnerabilitiesOverTime: {
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      query: getVulnerabilitiesOverTime,
      variables() {
        const startDate = formatDate(
          getDateInPast(new Date(), this.$options.defaultStartDate),
          'isoDate',
        );
        const endDate = formatDate(new Date(), 'isoDate');

        return {
          startDate,
          endDate,
          projectId: this.filters.projectId,
          reportType: this.filters.reportType,
          fullPath: this.groupFullPath,
          includeBySeverity: this.isGroupedBy('severity'),
          includeByReportType: this.isGroupedBy('reportType'),
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
    };
  },
  computed: {
    hasChartData() {
      return this.vulnerabilitiesOverTime.length > 0;
    },
  },
  methods: {
    isGroupedBy(group) {
      return this.groupedBy === group;
    },
    groupBy(group) {
      this.groupedBy = group;
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
      <gl-button-group>
        <gl-button
          data-testid="severity-button"
          size="small"
          category="secondary"
          :selected="isGroupedBy('severity')"
          @click="groupBy('severity')"
        >
          {{ s__('SecurityReports|Severity') }}
        </gl-button>
        <gl-button
          data-testid="report-type-button"
          size="small"
          category="secondary"
          :selected="isGroupedBy('reportType')"
          @click="groupBy('reportType')"
        >
          {{ s__('SecurityReports|Report Type') }}
        </gl-button>
      </gl-button-group>
    </template>
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
