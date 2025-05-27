<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { SCANNER_POPOVER_GROUPS, SCANNER_TYPES } from '../constants';
import ToolCoverageDetails from './tool_coverage_details.vue';

export default {
  components: { GlBadge, GlPopover, ToolCoverageDetails },
  props: {
    securityScanners: {
      type: Array,
      required: false,
      default: () => [],
    },
    projectName: {
      type: String,
      required: true,
    },
  },
  methods: {
    getRelevantStatuses(scannerTypes) {
      return scannerTypes.map((type) => {
        const existingStatus = this.securityScanners.find((status) => status.analyzerType === type);
        return existingStatus || { analyzerType: type };
      });
    },
    scannerStyling(scannerTypes) {
      const relevantStatuses = this.getRelevantStatuses(scannerTypes);
      if (relevantStatuses.some((status) => status.status === 'FAILED')) {
        return { variant: 'danger', class: 'gl-border-red-600' };
      }
      if (relevantStatuses.some((status) => status.status === 'SUCCESS')) {
        return { variant: 'success', class: 'gl-border-transparent' };
      }
      // otherwise assume status is SCANNER_DISABLED
      return { class: '!gl-bg-default !gl-text-neutral-600 gl-border-gray-200 gl-border-dashed' };
    },
    getToolCoverageTitle(key) {
      return SCANNER_TYPES[key].name;
    },
    getLabel(key) {
      return SCANNER_TYPES[key].textLabel;
    },
  },
  SCANNER_POPOVER_GROUPS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-gap-2">
    <div v-for="(value, key) in $options.SCANNER_POPOVER_GROUPS" :key="key">
      <gl-badge
        :id="`tool-coverage-${key}-${projectName}`"
        v-bind="scannerStyling(value)"
        class="gl-border gl-w-8 gl-text-xs gl-font-bold"
        :data-testid="`badge-${key}-${projectName}`"
      >
        {{ getLabel(key) }}
      </gl-badge>
      <gl-popover
        :css-classes="['gl-max-w-full']"
        :title="getToolCoverageTitle(key)"
        :target="`tool-coverage-${key}-${projectName}`"
        :data-testid="`popover-${key}-${projectName}`"
        show-close-button
      >
        <tool-coverage-details :is-project="true" :security-scanner="getRelevantStatuses(value)" />
      </gl-popover>
    </div>
  </div>
</template>
