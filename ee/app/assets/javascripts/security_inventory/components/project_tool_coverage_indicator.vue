<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { filterSecurityScanners } from 'ee/security_inventory/utils';
import { SCANNER_POPOVER_GROUPS, SCANNER_TYPES } from '../constants';
import ToolCoverageDetails from './tool_coverage_details.vue';

export default {
  components: { GlBadge, GlPopover, ToolCoverageDetails },
  props: {
    securityScanners: {
      type: Object,
      required: false,
      default: () => ({
        enabled: [],
        pipelineRun: [],
      }),
    },
    projectName: {
      type: String,
      required: true,
    },
    // TODO: switch to object with status enum
    //    scanners: {
    //      type: Object,
    //      required: false,
    //      default: () => ({
    //        SAST: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //        DAST: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //        SAST_IAC: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //        SECRET_DETECTION: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //        DEPENDENCY_SCANNING: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //        CONTAINER_SCANNING: {
    //          status: 'SCANNER_DISABLED'
    //        },
    //      })
    //    }
  },
  methods: {
    isEnabled(scannerTypes) {
      return (
        scannerTypes.some((item) => this.securityScanners.enabled?.includes(item)) &&
        scannerTypes.some((item) => this.securityScanners.pipelineRun?.includes(item))
      );
    },
    isFailed(scannerTypes) {
      return (
        scannerTypes.some((item) => this.securityScanners.enabled?.includes(item)) &&
        !scannerTypes.some((item) => this.securityScanners.pipelineRun?.includes(item))
      );
    },
    scannerStyling(scannerTypes) {
      if (this.isEnabled(scannerTypes)) {
        // TODO: replace with this.scanners[scanner].status === 'SCANNER_ENABLED'
        return { variant: 'success', class: 'gl-border-transparent' };
      }
      if (this.isFailed(scannerTypes)) {
        // TODO: replace with this.scanners[scanner].status === 'SCANNER_FAILED'
        return { variant: 'danger', class: 'gl-border-red-600' };
      }
      // otherwise assume status is SCANNER_DISABLED
      return { class: '!gl-bg-default !gl-text-neutral-600 gl-border-gray-200 gl-border-dashed' };
    },
    getToolCoverageTitle(key) {
      return SCANNER_TYPES[key].name;
    },
    getSecurityScanner(scannerTypes) {
      return filterSecurityScanners(scannerTypes, this.securityScanners);
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
        <tool-coverage-details :is-project="true" :security-scanner="getSecurityScanner(value)" />
      </gl-popover>
    </div>
  </div>
</template>
