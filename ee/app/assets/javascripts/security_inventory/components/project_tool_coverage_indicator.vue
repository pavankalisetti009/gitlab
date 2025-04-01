<script>
import { GlBadge } from '@gitlab/ui';
import { SCANNERS } from '../constants';

export default {
  name: 'ProjectToolCoverageIndicator',
  components: { GlBadge },
  props: {
    securityScanners: {
      type: Object,
      required: false,
      default: () => ({
        enabled: [],
        pipelineRun: [],
      }),
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
      return { class: '!gl-bg-default gl-border-gray-200 gl-border-dashed' };
    },
  },
  SCANNERS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-gap-2">
    <gl-badge
      v-for="{ scanner, label } in $options.SCANNERS"
      :key="scanner"
      v-bind="scannerStyling(scanner)"
      class="gl-border gl-w-8 gl-text-xs gl-font-bold"
      :data-testid="`${scanner}-badge`"
    >
      {{ label }}
    </gl-badge>
  </div>
</template>
