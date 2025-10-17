<script>
import { GlDashboardLayout } from '@gitlab/ui';
import { s__ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import ProjectVulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/project_vulnerabilities_for_severity_panel.vue';
import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';

const REPORT_TYPE_TOKEN_DEFINITION = {
  type: 'reportType',
  title: s__('SecurityReports|Report type'),
  multiSelect: true,
  unique: true,
  token: markRaw(ReportTypeToken),
  operators: OPERATORS_OR,
  reportTypes: {
    ...REPORT_TYPES_WITH_MANUALLY_ADDED,
    ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
    ...REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  },
};

export default {
  components: {
    GlDashboardLayout,
    FilteredSearch,
  },
  mixins: [glFeatureFlagMixin()],
  data() {
    return {
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
          ...generateVulnerabilitiesForSeverityPanels({
            panelComponent: ProjectVulnerabilitiesForSeverityPanel,
            filters: this.filters,
          }),
          {
            id: '1',
            component: markRaw(VulnerabilitiesOverTimePanel),
            componentProps: {
              scope: 'project',
              filters: this.filters,
            },
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
  },
  methods: {
    updateFilters(newFilters) {
      this.filters = newFilters;
    },
  },
  filteredSearchTokens: [REPORT_TYPE_TOKEN_DEFINITION],
};
</script>

<template>
  <gl-dashboard-layout :config="dashboard" data-testid="project-security-dashboard-new">
    <template #filters>
      <filtered-search :tokens="$options.filteredSearchTokens" @filters-changed="updateFilters" />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
