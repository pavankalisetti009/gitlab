<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button.vue';
import VulnerabilitySeverities from './project_security_status_chart.vue';
import VulnerabilitiesOverTimeChart from './vulnerabilities_over_time_chart.vue';

export default {
  components: {
    VulnerabilitiesOverTimeChart,
    VulnerabilitySeverities,
    PageHeading,
    PdfExportButton,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['groupFullPath'],
  props: {
    historyQuery: {
      type: Object,
      required: true,
    },
    gradesQuery: {
      type: Object,
      required: true,
    },
    showExport: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      vulnerabilitiesChartFn: null,
    };
  },
  computed: {
    showExportButton() {
      return this.showExport && this.glFeatures.vulnerabilitiesPdfExport;
    },
  },
  methods: {
    getReportData() {
      return {
        group_vulnerabilities_over_time: this.vulnerabilitiesChartFn?.() || {},
        full_path: this.groupFullPath,
      };
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('SecurityReports|Security dashboard')">
      <template #actions>
        <pdf-export-button v-if="showExportButton" :get-report-data="getReportData" />
      </template>
    </page-heading>

    <div class="security-charts gl-grid">
      <vulnerabilities-over-time-chart
        :query="historyQuery"
        @chart-report-data-registered="vulnerabilitiesChartFn = $event"
      />
      <vulnerability-severities :query="gradesQuery" />
    </div>
  </div>
</template>
