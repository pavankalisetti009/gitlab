<script>
import { s__ } from '~/locale';
import SmartInterval from '~/smart_interval';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import { transformToEnabledScans } from 'ee/vue_merge_request_widget/widgets/security_reports/utils';
import SummaryText, {
  MAX_NEW_VULNERABILITIES,
} from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';

const POLL_INTERVAL = 3000;
const MAX_POLL_INTERVAL = 30000;

export default {
  name: 'SecurityFindingsPage',
  components: {
    SummaryText,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      enabledScans: {
        full: {},
        partial: {},
      },
      enabledScansTransformed: [],
      reportsByScanType: {
        full: {},
        partial: {},
      },
      reportPollers: {},
      isLoading: true,
      hasAtLeastOneReportWithMaxNewVulnerabilities: false,
      errorMessage: '',
    };
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.targetProjectFullPath,
          pipelineIid: this.pipelineIid,
        };
      },
      update({ project }) {
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        const scans = project.pipeline;
        const isReady = scans.enabledSecurityScans?.ready === true;

        if (!isReady && !this.$options.pollingInterval) {
          this.initPolling();
        }

        if (isReady && this.$options.pollingInterval) {
          this.$options.pollingInterval.destroy();
          this.$options.pollingInterval = undefined;
        }

        this.enabledScansTransformed = transformToEnabledScans(scans);

        if (isReady && this.enabledScansTransformed.length > 0) {
          this.fetchAllFindingReports();
        }

        return {
          full: scans.enabledSecurityScans || {},
          partial: scans.enabledPartialSecurityScans || {},
        };
      },
      error() {
        this.errorMessage = s__(
          'ciReport|Error while fetching enabled scans. Please try again later.',
        );
      },
      skip() {
        return !this.pipelineIid || !this.targetProjectFullPath;
      },
    },
  },
  computed: {
    pipelineIid() {
      return this.mr.pipeline?.iid;
    },
    targetProjectFullPath() {
      return this.mr.targetProjectFullPath;
    },
    hasActivePollers() {
      return Object.keys(this.reportPollers).length > 0;
    },
    isLoadingEnabledScans() {
      return this.$apollo.queries.enabledScans?.loading || Boolean(this.$options.pollingInterval);
    },
    hasEnabledScans() {
      const isEnabled = (scans) =>
        Object.entries(scans)
          .filter(([key]) => key !== 'ready' && key !== '__typename')
          .some(([, value]) => value === true);

      return isEnabled(this.enabledScans.full) || isEnabled(this.enabledScans.partial);
    },
    shouldRenderMrWidget() {
      if (this.isLoadingEnabledScans) {
        return false;
      }

      return !this.mr.isPipelineActive && this.hasEnabledScans;
    },
    totalNewFindings() {
      const sumFindings = (reports) =>
        Object.values(reports).reduce((sum, report) => sum + (report.numberOfNewFindings || 0), 0);

      return sumFindings(this.reportsByScanType.full) + sumFindings(this.reportsByScanType.partial);
    },
  },
  beforeDestroy() {
    if (this.$options.pollingInterval) {
      this.$options.pollingInterval.destroy();
    }
    Object.values(this.reportPollers).forEach((poller) => poller.destroy());
  },
  methods: {
    initPolling() {
      this.$options.pollingInterval = new SmartInterval({
        callback: () => this.$apollo.queries.enabledScans.refetch(),
        startingInterval: POLL_INTERVAL,
        incrementByFactorOf: 1,
        immediateExecution: true,
      });
    },
    async fetchAllFindingReports() {
      const fetchPromises = this.enabledScansTransformed.map(({ reportType, scanMode }) =>
        this.fetchFindingReports(reportType, scanMode),
      );
      await Promise.all(fetchPromises);

      if (!this.hasActivePollers) {
        this.isLoading = false;
      }
    },
    async fetchFindingReports(reportType, scanMode) {
      const scanModeKey = scanMode === 'PARTIAL' ? 'partial' : 'full';

      const result = await this.$apollo.query({
        query: findingReportsComparerQuery,
        variables: {
          fullPath: this.targetProjectFullPath,
          iid: String(this.mr.iid),
          reportType,
          scanMode,
        },
        fetchPolicy: 'no-cache',
      });

      const data = result.data?.project?.mergeRequest?.findingReportsComparer;

      if (data?.status !== 'PARSED') {
        this.startReportPolling(reportType, scanMode);
        return;
      }

      this.stopReportPolling(reportType, scanMode);

      // GraphQL responses are read-only, so clone to enable mutations
      // Allows "updateFindingState" to show dismissed badge changes immediately without refresh
      const added = data.report?.added?.map((finding) => ({ ...finding })) || [];
      const fixed = data.report?.fixed?.map((finding) => ({ ...finding })) || [];

      if (added.length === MAX_NEW_VULNERABILITIES) {
        this.hasAtLeastOneReportWithMaxNewVulnerabilities = true;
      }

      const report = {
        reportType,
        status: data?.status,
        added,
        fixed,
        numberOfNewFindings: added.length,
        numberOfFixedFindings: fixed.length,
      };

      this.reportsByScanType[scanModeKey] = {
        ...this.reportsByScanType[scanModeKey],
        [reportType]: report,
      };
    },
    startReportPolling(reportType, scanMode) {
      const key = `${reportType}_${scanMode}`;

      if (this.reportPollers[key]) return;

      this.reportPollers[key] = new SmartInterval({
        callback: () => this.fetchFindingReports(reportType, scanMode),
        startingInterval: POLL_INTERVAL,
        maxInterval: MAX_POLL_INTERVAL,
        incrementByFactorOf: 1.5,
        immediateExecution: false,
      });
    },
    stopReportPolling(reportType, scanMode) {
      const key = `${reportType}_${scanMode}`;
      if (this.reportPollers[key]) {
        this.reportPollers[key].destroy();
        delete this.reportPollers[key];

        if (!this.hasActivePollers) {
          this.isLoading = false;
        }
      }
    },
  },
  pollingInterval: undefined,
};
</script>

<template>
  <div v-if="shouldRenderMrWidget" data-testid="security-findings-page">
    <summary-text
      :total-new-vulnerabilities="totalNewFindings"
      :is-loading="isLoading"
      :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
    />
  </div>
</template>
