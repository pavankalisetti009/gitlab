<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import groupVulnerabilityByAge from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_by_age.query.graphql';
import PanelSeverityFilter from './panel_severity_filter.vue';
import PanelGroupBy from './panel_group_by.vue';

const PANEL_ID = 'vulnerabilitiesByAge';
const GROUP_BY_DEFAULT = 'severity';

export default {
  name: 'VulnerabilitiesByAgePanel',
  components: {
    ExtendedDashboardPanel,
    PanelSeverityFilter,
    PanelGroupBy,
  },
  inject: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      hasFetchError: false,
      vulnerabilitiesByAge: [],
      severity: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        defaultValue: [],
      }),
      groupedBy: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        defaultValue: GROUP_BY_DEFAULT,
      }),
    };
  },
  apollo: {
    vulnerabilitiesByAge: {
      query: groupVulnerabilityByAge,
      variables() {
        return {
          ...this.filters,
          fullPath: this.fullPath,
          severity: this.severity,
        };
      },
      update(data) {
        return data?.group?.securityMetrics?.vulnerabilitiesByAge || [];
      },
      error() {
        this.hasFetchError = true;
      },
    },
  },
  watch: {
    severity(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        value,
        defaultValue: [],
      });
    },
    groupedBy(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        value,
        defaultValue: GROUP_BY_DEFAULT,
      });
    },
  },
  tooltip: {
    description: s__(
      'SecurityReports|Open vulnerabilities by the amount of time since they were opened.',
    ),
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities by age')"
    :loading="$apollo.queries.vulnerabilitiesByAge.loading"
    :show-alert-state="hasFetchError"
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <panel-severity-filter v-model="severity" class="gl-mr-2" />
      <panel-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <pre>{{ vulnerabilitiesByAge }}</pre>
    </template>
  </extended-dashboard-panel>
</template>
