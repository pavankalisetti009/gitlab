<script>
import projectVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import groupVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import VulnerabilitiesForSeverityPanel from './charts/vulnerabilities_for_severity_panel.vue';

const SCOPE_CONFIG = {
  project: {
    query: projectVulnerabilitiesPerSeverityCount,
    pageLevelFilters: ['reportType'],
  },
  group: {
    query: groupVulnerabilitiesPerSeverityCount,
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesForSeverityWrapper',
  components: {
    VulnerabilitiesForSeverityPanel,
  },
  inject: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (value) => Object.keys(SCOPE_CONFIG).includes(value),
    },
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
      query() {
        return this.config.query;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          ...this.queryVariables,
        };
      },
      update(data) {
        return (
          data.namespace?.securityMetrics?.vulnerabilitiesPerSeverity?.[this.severity]?.count || 0
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
    config() {
      return SCOPE_CONFIG[this.scope];
    },
    queryVariables() {
      return this.config.pageLevelFilters.reduce((acc, key) => {
        if (this.filters[key] !== undefined) {
          acc[key] = this.filters[key];
        }
        return acc;
      }, {});
    },
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
