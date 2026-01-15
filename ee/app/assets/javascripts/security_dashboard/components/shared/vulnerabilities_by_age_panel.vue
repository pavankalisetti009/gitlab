<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';

export default {
  name: 'VulnerabilitiesByAgePanel',
  components: {
    ExtendedDashboardPanel,
  },
};
</script>

<template>
  <extended-dashboard-panel :title="s__('SecurityReports|Vulnerabilities by age')" />
</template>
