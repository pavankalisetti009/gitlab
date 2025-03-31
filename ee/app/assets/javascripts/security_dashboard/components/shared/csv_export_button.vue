<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { formatDate } from '~/lib/utils/datetime_utility';
import download from '~/lib/utils/downloader';
import pollUntilComplete from '~/lib/utils/poll_until_complete';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import { DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT } from '../../constants';

export default {
  name: 'CsvExportButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['vulnerabilitiesExportEndpoint', 'dashboardType'],
  data() {
    return {
      isPreparingCsvExport: false,
    };
  },
  computed: {
    asyncExportEnabled() {
      switch (this.dashboardType) {
        case DASHBOARD_TYPE_PROJECT:
          return this.glFeatures?.asynchronousVulnerabilityExportDeliveryForProjects;
        case DASHBOARD_TYPE_GROUP:
          return this.glFeatures?.asynchronousVulnerabilityExportDeliveryForGroups;
        default:
          return false;
      }
    },
    exportTooltip() {
      return this.asyncExportEnabled
        ? s__('SecurityReports|Send as CSV to email')
        : s__('SecurityReports|Export as CSV');
    },
  },
  methods: {
    initiateCsvExport() {
      this.isPreparingCsvExport = true;

      if (this.asyncExportEnabled) {
        this.startAsyncExport();
      } else {
        this.startSyncExport();
      }
    },

    startAsyncExport() {
      axios
        .post(this.vulnerabilitiesExportEndpoint, { send_email: true })
        .then(() => {
          this.notifyUserReportWillBeEmailed();
        })
        .catch(() => {
          this.notifyUserOfExportError();
        })
        .finally(() => {
          this.isPreparingCsvExport = false;
        });
    },

    startSyncExport() {
      axios
        .post(this.vulnerabilitiesExportEndpoint)
        .then(({ data }) => pollUntilComplete(data._links.self))
        .then(({ data }) => {
          if (data.status !== 'finished') {
            throw new Error();
          }
          download({
            fileName: `csv-export-${formatDate(new Date(), 'isoDateTime')}.csv`,
            url: data._links.download,
          });
        })
        .catch(() => {
          this.notifyUserOfExportError();
        })
        .finally(() => {
          this.isPreparingCsvExport = false;
        });
    },

    notifyUserReportWillBeEmailed() {
      createAlert({
        message: s__(
          'SecurityReports|The report is being generated and will be sent to your email.',
        ),
        variant: 'info',
        dismissible: true,
      });
    },

    notifyUserOfExportError() {
      createAlert({
        message: s__('SecurityReports|There was an error while generating the report.'),
        variant: 'danger',
        dismissible: true,
      });
    },
  },
};
</script>
<template>
  <gl-button
    v-gl-tooltip.hover
    :title="exportTooltip"
    :loading="isPreparingCsvExport"
    :icon="isPreparingCsvExport ? '' : 'export'"
    :disabled="!vulnerabilitiesExportEndpoint"
    @click="initiateCsvExport"
  >
    {{ s__('SecurityReports|Export') }}
  </gl-button>
</template>
