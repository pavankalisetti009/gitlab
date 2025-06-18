<script>
import { s__, __ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';

export default {
  components: {
    DashboardLayout,
    PanelsBase,
    VulnerabilitiesOverTimeChart,
  },
  inject: ['groupFullPath'],
  apollo: {
    vulnerabilitiesOverTime: {
      query: getVulnerabilitiesOverTime,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      update(data) {
        return data.group?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
      },
      error() {
        this.errorStates.vulnerabilitiesOverTime = true;
      },
    },
  },
  data() {
    return {
      vulnerabilitiesOverTime: [],
      errorStates: {
        vulnerabilitiesOverTime: false,
      },
    };
  },
  computed: {
    dashboard() {
      return {
        title: s__('SecurityReports|Security dashboard'),
        description: s__(
          // Note: This is just a placeholder text and will be replaced with the final copy, once it is ready
          'SecurityReports|This dashboard provides an overview of your security vulnerabilities.',
        ),
        panels: [
          {
            id: '1',
            title: __('Vulnerabilities over time'),
            component: markRaw(VulnerabilitiesOverTimeChart),
            componentProps: {
              chartSeries: this.vulnerabilitiesOverTimeSeries,
            },
            loading: this.$apollo.queries.vulnerabilitiesOverTime.loading,
            showAlertState: this.errorStates.vulnerabilitiesOverTime,
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 0,
              xPos: 0,
            },
          },
        ],
      };
    },
    vulnerabilitiesOverTimeSeries() {
      return formatVulnerabilitiesOverTimeData(this.vulnerabilitiesOverTime);
    },
  },
};
</script>

<template>
  <dashboard-layout :config="dashboard" data-testid="security-dashboard-new">
    <template #panel="{ panel }">
      <panels-base v-bind="panel">
        <template #body>
          <component
            :is="panel.component"
            v-if="!panel.showAlertState"
            class="gl-h-full gl-overflow-hidden"
            v-bind="panel.componentProps"
          />
          <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
        </template>
      </panels-base>
    </template>
  </dashboard-layout>
</template>
