<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { SCANNERS } from '../constants';
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
    isEnabled(scanner) {
      return (
        this.securityScanners.enabled?.includes(scanner) &&
        this.securityScanners.pipelineRun?.includes(scanner)
      );
    },
    isFailed(scanner) {
      return (
        this.securityScanners.enabled?.includes(scanner) &&
        !this.securityScanners.pipelineRun?.includes(scanner)
      );
    },
    scannerStyling(scanner) {
      if (this.isEnabled(scanner)) {
        // TODO: replace with this.scanners[scanner].status === 'SCANNER_ENABLED'
        return { variant: 'success', class: 'gl-border-transparent' };
      }
      if (this.isFailed(scanner)) {
        // TODO: replace with this.scanners[scanner].status === 'SCANNER_FAILED'
        return { variant: 'danger', class: 'gl-border-red-600' };
      }
      // otherwise assume status is SCANNER_DISABLED
      return { class: '!gl-bg-default !gl-text-neutral-600 gl-border-gray-200 gl-border-dashed' };
    },
    getToolCoverageTitle(scanner) {
      return SCANNERS.find((item) => {
        return item.scanner === scanner;
      }).name;
    },
  },
  SCANNERS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-gap-2">
    <div v-for="{ scanner, label } in $options.SCANNERS" :key="label">
      <gl-badge
        :id="`tool-coverage-${label}-${projectName}`"
        v-bind="scannerStyling(scanner)"
        class="gl-border gl-w-8 gl-text-xs gl-font-bold"
        :data-testid="`badge-${label}-${projectName}`"
      >
        {{ label }}
      </gl-badge>
      <gl-popover
        :title="getToolCoverageTitle(scanner)"
        :target="`tool-coverage-${label}-${projectName}`"
        :data-testid="`popover-${label}-${projectName}`"
        show-close-button
      >
        <tool-coverage-details />
      </gl-popover>
    </div>
  </div>
</template>
