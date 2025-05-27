<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { SCANNER_POPOVER_LABELS } from 'ee/security_inventory/constants';
import { securityScannerValidator } from 'ee/security_inventory/utils';

// These statuses represent the situations that can be displayed in the icon
const STATUS_CONFIG = {
  SUCCESS: { name: 'check-circle-filled', variant: 'success', text: __('Enabled') },
  FAILED: { name: 'status-failed', variant: 'danger', text: __('Failed') },
  DEFAULT: { name: 'clear', variant: 'disabled', text: __('Not enabled') },
};

export default {
  name: 'ToolCoverageDetails',
  components: {
    GlButton,
    GlIcon,
  },
  props: {
    securityScanner: {
      type: Array,
      required: false,
      default: () => [],
      validator: (value) => securityScannerValidator(value),
    },
    isProject: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    scannerItems() {
      return this.securityScanner.map((scanner) => ({
        title: SCANNER_POPOVER_LABELS[scanner.analyzerType] || __('Status'),
        status: scanner.status,
        analyzerType: scanner.analyzerType,
      }));
    },
    // TODO: to expose when we got the relevant data from the API
    // lastScan() {
    //   // TODO: Implement last scan logic here
    //   return false;
    // },
  },
  methods: {
    getStatusConfig(status) {
      return STATUS_CONFIG[status] || STATUS_CONFIG.DEFAULT;
    },
  },
  i18n: {
    vulnerabilityReportButton: s__('ToolCoverageDetails|Manage configuration'),
  },
};
</script>

<template>
  <div>
    <div class="gl-m-2">
      <div v-for="(item, index) in scannerItems" :key="index" class="gl-my-2">
        <span class="gl-font-bold" :data-testid="`scanner-title-${index}`">{{ item.title }}:</span>
        <gl-icon
          :name="getStatusConfig(item.status).name"
          :variant="getStatusConfig(item.status).variant"
          :size="12"
        />
        <span :data-testid="`scanner-status-${index}`">
          {{ getStatusConfig(item.status).text }}
        </span>
      </div>

      <!--      TODO: to expose when we got the relevant data from the API-->
      <!--      <div class="gl-my-2" data-testid="last-scan">-->
      <!--        <span class="gl-font-bold">{{ __('Last scan:') }}</span>-->
      <!--        <span v-if="lastScan">{{ lastScan }}</span>-->
      <!--        <gl-icon v-else name="dash" />-->
      <!--      </div>-->
    </div>

    <gl-button
      v-if="isProject"
      category="secondary"
      variant="confirm"
      class="gl-my-3 gl-w-full"
      size="small"
      >{{ $options.i18n.vulnerabilityReportButton }}</gl-button
    >
  </div>
</template>
