<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { SCANNER_POPOVER_LABELS } from 'ee/security_inventory/constants';

export default {
  name: 'ToolCoverageDetails',
  components: {
    GlButton,
    GlIcon,
  },
  props: {
    securityScanner: {
      type: Object,
      required: false,
      default: () => ({
        scannerTypes: [],
        enabled: [],
        pipelineRun: [],
      }),
    },
    isProject: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    scannerTitles() {
      return this.securityScanner.scannerTypes.map(
        (scannerType) => SCANNER_POPOVER_LABELS[scannerType] || __('Status'),
      );
    },
    // TODO: to expose when we got the relevant data from the API
    // lastScan() {
    //   // TODO: Implement last scan logic here
    //   return false;
    // },
  },
  methods: {
    enabledStatus(title) {
      const index = this.scannerTitles.indexOf(title);
      return Boolean(this.securityScanner.enabled[index]);
    },
  },
  i18n: {
    vulnerabilityReportButton: s__('ToolCoverageDetails|Manage configuration'),
  },
};
</script>

<template>
  <div>
    <div>
      <div v-for="(title, index) in scannerTitles" :key="index" class="gl-my-2">
        <span class="gl-font-bold" :data-testid="`scanner-title-${index}`">{{ title }}:</span>
        <gl-icon
          :name="enabledStatus(title) ? 'check-circle-filled' : 'clear'"
          :class="enabledStatus(title) ? 'enabled' : 'disabled'"
          :variant="enabledStatus(title) ? 'success' : 'disabled'"
          :size="12"
        />
        <span :data-testid="`scanner-status-${index}`">
          {{ enabledStatus(title) ? __('Enabled') : __('Not enabled') }}
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
