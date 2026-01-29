<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
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
      vulnerabilitySeveritiesChartFn: null,
    };
  },
  computed: {
    showExportButton() {
      return this.showExport;
    },
  },
  methods: {
    getReportData() {
      return {
        group_vulnerabilities_over_time: this.vulnerabilitiesChartFn?.() || {},
        project_security_status: this.vulnerabilitySeveritiesChartFn?.() || {},
        full_path: this.groupFullPath,
      };
    },
  },
};
</script>

<template>
  <div data-testid="security-dashboard">
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
      <vulnerability-severities
        :query="gradesQuery"
        @chart-report-data-registered="vulnerabilitySeveritiesChartFn = $event"
      />
    </div>
  </div>
</template>
