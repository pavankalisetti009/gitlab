<script>
import projectVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import VulnerabilitiesForSeverityPanel from './charts/vulnerabilities_for_severity_panel.vue';

export default {
  name: 'ProjectVulnerabilitiesForSeverityPanel',
  components: {
    VulnerabilitiesForSeverityPanel,
  },
  inject: ['projectFullPath'],
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
      query: projectVulnerabilitiesPerSeverityCount,
      variables() {
        return {
          fullPath: this.projectFullPath,
          reportType: this.filters.reportType,
        };
      },
      update(data) {
        return (
          data.project?.securityMetrics?.vulnerabilitiesPerSeverity?.[this.severity]?.count || 0
        );
      },
      error() {
        this.hasFetchError = true;
      },
    },
  },
  data() {
    return {
      hasFetchError: false,
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
    :filters="filters"
    :loading="loading"
    :error="hasFetchError"
  />
</template>
