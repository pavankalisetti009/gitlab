<script>
import { GlDashboardPanel } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { SEVERITY_CLASS_NAME_MAP } from 'ee/vue_shared/security_reports/components/constants';
import { SEVERITY_LEVELS_KEYS, SEVERITY_LEVELS } from 'ee/security_dashboard/constants';

export default {
  name: 'VulnerabilitiesForSeverityPanel',
  components: {
    GlDashboardPanel,
    GlSingleStat,
  },
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
      return `severity-${this.severity}`;
    },
    iconClass() {
      return `gl-mr-3 ${SEVERITY_CLASS_NAME_MAP[this.severity]}`;
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
  >
    <template #body>
      <gl-single-stat v-if="!error" title="" :value="count" />
      <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </gl-dashboard-panel>
</template>
