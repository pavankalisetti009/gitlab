<script>
import { s__, __ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue';

const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: markRaw(ProjectToken),
  operators: OPERATORS_OR,
};

export default {
  components: {
    DashboardLayout,
    FilteredSearch,
    PanelsBase,
    VulnerabilitiesOverTimeChart,
  },
  inject: ['groupFullPath'],
  apollo: {
    vulnerabilitiesOverTime: {
      query: getVulnerabilitiesOverTime,
      variables() {
        const { projectId } = this.filters;

        return {
          fullPath: this.groupFullPath,
          ...(projectId ? { projectId } : {}),
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
      filters: {},
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
  methods: {
    updateFilters(newFilters) {
      if (Object.keys(newFilters).length === 0) {
        this.filters = {};
      } else {
        this.filters = { ...this.filters, ...newFilters };
      }
    },
  },
  filteredSearchTokens: [PROJECT_TOKEN_DEFINITION],
};
</script>

<template>
  <dashboard-layout :config="dashboard" data-testid="security-dashboard-new">
    <template #filters>
      <filtered-search :tokens="$options.filteredSearchTokens" @filters-changed="updateFilters" />
    </template>
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
