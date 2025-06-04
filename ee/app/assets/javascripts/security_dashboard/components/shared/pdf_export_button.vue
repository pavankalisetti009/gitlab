<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert, VARIANT_INFO } from '~/alert';

export default {
  name: 'PdfExportButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  data() {
    return {
      isExporting: false,
    };
  },
  methods: {
    notifyUserReportWillBeEmailed() {
      createAlert({
        message: s__(
          'SecurityReports|Report export in progress. After the report is generated, an email will be sent with the download link.',
        ),
        variant: VARIANT_INFO,
        dismissible: true,
      });
    },
    async onClickExport() {
      this.isExporting = true;
      this.notifyUserReportWillBeEmailed();
    },
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip
    :title="s__('SecurityReports|Export as PDF')"
    category="secondary"
    class="gl-ml-2"
    :loading="isExporting"
    :icon="isExporting ? '' : 'export'"
    @click="onClickExport"
  >
    {{ s__('SecurityReports|Export') }}
  </gl-button>
</template>
