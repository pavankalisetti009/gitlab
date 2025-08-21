<script>
import groupVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import VulnerabilitiesForSeverityPanel from './charts/vulnerabilities_for_severity_panel.vue';

export default {
  name: 'GroupVulnerabilitiesForSeverityPanel',
  components: {
    VulnerabilitiesForSeverityPanel,
  },
  inject: ['groupFullPath'],
  props: {
    severity: {
      type: String,
      required: true,
    },
    filters: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    vulnerabilitySeverityCount: {
      query: groupVulnerabilitiesPerSeverityCount,
      variables() {
        return {
          fullPath: this.groupFullPath,
          projectId: this.filters.projectId,
          reportType: this.filters.reportType,
        };
      },
      update(data) {
        return data.group?.securityMetrics?.vulnerabilitiesPerSeverity?.[this.severity] || 0;
      },
      error() {
        this.fetchError = true;
      },
    },
  },
  data() {
    return {
      fetchError: false,
      vulnerabilitySeverityCount: 0,
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.vulnerabilitySeverityCount.loading;
    },
  },
};
</script>

<template>
  <vulnerabilities-for-severity-panel
    :severity="severity"
    :count="vulnerabilitySeverityCount"
    :loading="loading"
    :error="fetchError"
  />
</template>
