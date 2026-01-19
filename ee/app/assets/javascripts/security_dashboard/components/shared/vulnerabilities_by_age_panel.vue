<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
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
  data() {
    return {
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
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <panel-severity-filter v-model="severity" class="gl-mr-2" />
      <panel-group-by v-model="groupedBy" />
    </template>
  </extended-dashboard-panel>
</template>
