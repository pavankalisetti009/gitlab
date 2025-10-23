<script>
import { GlDashboardLayout } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/project_token.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import GroupRiskScorePanel from 'ee/security_dashboard/components/shared/group_risk_score_panel.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import {
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';

const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: markRaw(ProjectToken),
  operators: OPERATORS_OR,
};

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
            scope: 'group',
            filters: this.filters,
          }),
          ...(this.glFeatures.newSecurityDashboardTotalRiskScore
            ? [
                {
                  id: 'risk-score',
                  component: markRaw(GroupRiskScorePanel),
                  componentProps: {
                    filters: this.filters,
                  },
                  gridAttributes: {
                    width: 5,
                    height: 4,
                    yPos: 0,
                    xPos: 0,
                  },
                },
              ]
            : []),
          {
            id: 'vulnerabilities-over-time',
            component: markRaw(VulnerabilitiesOverTimePanel),
            componentProps: {
              scope: 'group',
              filters: this.filters,
            },
            gridAttributes: {
              width: 7,
              height: 4,
              yPos: 0,
              // When the "Risk score" panel doesn't exist, this shifts "Vulnerabilities over time" to the left, removing the empty space.
              xPos: this.glFeatures.newSecurityDashboardTotalRiskScore ? 5 : 0,
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
  filteredSearchTokens: [PROJECT_TOKEN_DEFINITION, REPORT_TYPE_TOKEN_DEFINITION],
};
</script>

<template>
  <gl-dashboard-layout :config="dashboard" data-testid="group-security-dashboard-new">
    <template #filters>
      <filtered-search :tokens="$options.filteredSearchTokens" @filters-changed="updateFilters" />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
