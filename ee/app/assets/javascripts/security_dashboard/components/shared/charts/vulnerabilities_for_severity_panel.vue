<script>
import { GlDashboardPanel, GlLink } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { SEVERITY_CLASS_NAME_MAP } from 'ee/vue_shared/security_reports/components/constants';
import { SEVERITY_LEVELS_KEYS, SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { constructVulnerabilitiesReportWithFiltersPath } from 'ee/security_dashboard/utils/chart_utils';

export default {
  name: 'VulnerabilitiesForSeverityPanel',
  components: {
    GlDashboardPanel,
    GlSingleStat,
    GlLink,
  },
  inject: ['securityVulnerabilitiesPath'],
  props: {
    severity: {
      type: String,
      required: true,
      validator: (value) => SEVERITY_LEVELS_KEYS.includes(value),
    },
    count: {
      type: Number,
      required: true,
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    error: {
      type: Boolean,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    title() {
      return SEVERITY_LEVELS[this.severity];
    },
    icon() {
      if (this.error) {
        return 'error';
      }

      return `severity-${this.severity}`;
    },
    iconClass() {
      if (this.error) {
        return 'gl-text-red-500';
      }

      return `gl-mr-3 ${SEVERITY_CLASS_NAME_MAP[this.severity]}`;
    },
    link() {
      return constructVulnerabilitiesReportWithFiltersPath({
        securityVulnerabilitiesPath: this.securityVulnerabilitiesPath,
        seriesId: this.severity.toUpperCase(),
        filterKey: 'severity',
        additionalFilters: this.filters,
      });
    },
  },
};
</script>

<template>
  <gl-dashboard-panel
    :title="title"
    :title-icon="icon"
    :title-icon-class="iconClass"
    :loading="loading"
    :show-alert-state="error"
    :border-color-class="error ? 'gl-border-t-red-500' : ''"
  >
    <template #body>
      <div v-if="!error" class="-gl-mt-3">
        <gl-single-stat title="" :value="count" />
        <gl-link :href="link" target="_blank" class="gl-ml-2">{{ __('View') }}</gl-link>
      </div>
      <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </gl-dashboard-panel>
</template>
