<script>
import { GlButton, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import SmartInterval from '~/smart_interval';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  transformToEnabledScans,
  highlightsFromReport,
} from 'ee/vue_merge_request_widget/widgets/security_reports/utils';
import { reportTypes, i18n } from 'ee/vue_merge_request_widget/widgets/security_reports/i18n';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import StatusIcon from '~/vue_merge_request_widget/components/widget/status_icon.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import SummaryText, {
  MAX_NEW_VULNERABILITIES,
} from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';

const POLL_INTERVAL = 3000;
const MAX_POLL_INTERVAL = 30000;

export default {
  name: 'SecurityFindingsPage',
  components: {
    StatusIcon,
    SummaryText,
    SummaryHighlights,
    HelpPopover,
    GlButton,
    GlLink,
    ReportDetails,
    VulnerabilityFindingModal: () =>
      import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue'),
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
      modalData: null,
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
    reports() {
      return Object.keys(reportTypes)
        .filter(
          (reportType) =>
            this.reportsByScanType.full[reportType] || this.reportsByScanType.partial[reportType],
        )
        .map((reportType) => ({
          reportType,
          full: this.reportsByScanType.full[reportType],
          partial: this.reportsByScanType.partial[reportType],
        }));
    },
    totalNewFindings() {
      const sumFindings = (reports) =>
        Object.values(reports).reduce((sum, report) => sum + (report.numberOfNewFindings || 0), 0);

      return sumFindings(this.reportsByScanType.full) + sumFindings(this.reportsByScanType.partial);
    },
    highlights() {
      if (this.totalNewFindings === 0) {
        return {};
      }

      const highlights = {
        [CRITICAL]: 0,
        [HIGH]: 0,
        other: 0,
      };

      this.reports.forEach((report) => highlightsFromReport(report, highlights));

      return highlights;
    },
    statusIconName() {
      if (this.totalNewFindings > 0) {
        return EXTENSION_ICONS.warning;
      }

      if (this.errorMessage) {
        return EXTENSION_ICONS.error;
      }

      return EXTENSION_ICONS.success;
    },
    pipelineSecurityPath() {
      // Pipeline is loaded asynchronously via the MRWidgetService,
      // not available at initial page render, so we append the route segment here.
      // eslint-disable-next-line @gitlab/no-hardcoded-urls
      return `${this.mr.pipeline.path}/security`;
    },
    modalPipelineIid() {
      const iid = this.modalData?.vulnerability?.foundByPipelineIid;
      return iid ? Number(iid) : null;
    },
    branchRef() {
      return this.mr.sourceBranch;
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
        findings: [...added, ...fixed],
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
    setModalData(finding) {
      this.modalData = {
        error: null,
        title: finding.title,
        vulnerability: finding,
      };
    },
    clearModalData() {
      this.modalData = null;
    },
    updateFindingState(state) {
      this.modalData.vulnerability.state = state;
    },
  },
  pollingInterval: undefined,
  helpPopover: {
    options: { title: i18n.helpPopoverTitle },
    content: {
      text: i18n.helpPopoverContent,
      learnMorePath: helpPagePath('user/application_security/detect/security_scanning_results', {
        anchor: 'merge-request-security-widget',
      }),
    },
  },
};
</script>

<template>
  <div>
    <vulnerability-finding-modal
      v-if="modalData"
      :finding-uuid="modalData.vulnerability.uuid"
      :pipeline-iid="modalPipelineIid"
      :branch-ref="branchRef"
      :project-full-path="mr.targetProjectFullPath"
      :source-project-full-path="mr.sourceProjectFullPath"
      :show-ai-resolution="true"
      :merge-request-id="mr.id"
      data-testid="vulnerability-finding-modal"
      @hidden="clearModalData"
      @dismissed="updateFindingState('dismissed')"
      @detected="updateFindingState('detected')"
    />
    <div v-if="shouldRenderMrWidget" data-testid="security-findings-page">
      <div class="gl-flex">
        <status-icon :name="$options.name" :is-loading="isLoading" :icon-name="statusIconName" />
        <div class="gl-flex gl-grow gl-justify-between">
          <div>
            <summary-text
              :total-new-vulnerabilities="totalNewFindings"
              :is-loading="isLoading"
              :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
            />
            <summary-highlights
              v-if="!isLoading && totalNewFindings > 0"
              :highlights="highlights"
            />
          </div>
          <div class="gl-flex gl-items-center">
            <help-popover
              icon="information-o"
              :options="$options.helpPopover.options"
              class="gl-mr-3"
            >
              <p class="gl-mb-0">{{ $options.helpPopover.content.text }}</p>
              <gl-link
                :href="$options.helpPopover.content.learnMorePath"
                target="_blank"
                class="gl-text-sm"
              >
                {{ __('Learn more') }}
              </gl-link>
            </help-popover>
            <gl-button :href="pipelineSecurityPath">
              {{ s__('ciReport|View all pipeline findings') }}
            </gl-button>
          </div>
        </div>
      </div>
      <report-details
        v-for="report in reports"
        :key="report.reportType"
        :report="report"
        :mr="mr"
        :widget-name="$options.name"
        @modal-data="setModalData"
      />
    </div>
  </div>
</template>
