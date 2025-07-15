<script>
import { s__ } from '~/locale';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';

export default {
  components: {
    DashboardLayout,
  },
  computed: {
    dashboard() {
      return {
        title: s__('SecurityReports|Security dashboard'),
        description: s__(
          // Note: This is just a placeholder text and will be replaced with the final copy, once it is ready
          'SecurityReports|This dashboard provides an overview of your security vulnerabilities.',
        ),
        panels: [],
      };
    },
  },
};
</script>

<template>
  <dashboard-layout :config="dashboard" data-testid="project-security-dashboard-new" />
</template>
