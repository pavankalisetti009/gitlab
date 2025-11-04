<script>
import { visitUrl } from '~/lib/utils/url_utility';
import { historyPushState } from '~/lib/utils/common_utils';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import { convertToCamelCase } from '~/lib/utils/text_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import SmartInterval from '~/smart_interval';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import SummaryText, { MAX_NEW_VULNERABILITIES } from './summary_text.vue';
import SecurityTrainingPromoWidget from './security_training_promo_widget.vue';
import ReportDetails from './mr_widget_security_report_details.vue';
import { i18n, reportTypes } from './i18n';
import { highlightsFromReport } from './utils';

const POLL_INTERVAL = 3000;

// The backend returns the cached finding objects. Let's remove them as they may cause
// bugs. Instead, fetch the non-cached data when the finding modal is opened.
const getFindingWithoutFeedback = (finding) => ({
  ...finding,
  dismissal_feedback: undefined,
  merge_request_feedback: undefined,
  issue_feedback: undefined,
});

export default {
  name: 'WidgetSecurityReports',
  components: {
    VulnerabilityFindingModal: () =>
      import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue'),
    MrWidget,
    ReportDetails,
    SummaryText,
    SummaryHighlights,
    SecurityTrainingPromoWidget,
  },
  mixins: [glFeatureFlagMixin()],
  i18n,
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isLoading: true,
      hasAtLeastOneReportWithMaxNewVulnerabilities: false,
      modalData: null,
      topLevelErrorMessage: '',
      /**
       * Example data structure with all available fields:
       *
       * {
       *   full: {
       *     SAST: {
       *       reportType: 'SAST',
       *       reportTypeDescription: 'SAST',
       *.      numberOfNewFindings: 2,
       *       numberOfFixedFindings: 2,
       *       added: [Array], // typeof Finding
       *       fixed: [Array], // typeof Finding
       *       findings: [Array] // typeof Finding,
       *       testId: 'sast-scan-report'
       *     }
       *   }
       * }
       */
      reportsByScanType: {
        full: {},
        partial: {},
      },
      enabledScans: {
        partial: {},
        full: this.mr.enabledReports || {},
      },
    };
  },
  computed: {
    /**
     * Returns an array of reports in the following format:
     *
     * [
     *   { reportType: 'SAST', full: Report, partial: Report },
     *   { reportType: 'DAST', full: Report, partial: Report },
     *   // ...
     * ]
     */
    reports() {
      return Object.keys(reportTypes)
        .map((reportType) => {
          if (
            !this.reportsByScanType.full[reportType] &&
            !this.reportsByScanType.partial[reportType]
          ) {
            return undefined;
          }

          return {
            reportType,
            full: this.reportsByScanType.full[reportType],
            partial: this.reportsByScanType.partial[reportType],
          };
        })
        .filter((rt) => rt?.full || rt?.partial);
    },

    isCollapsible() {
      return this.reports.some(
        ({ full, partial }) =>
          full?.numberOfNewFindings ||
          full?.numberOfFixedFindings ||
          partial?.numberOfNewFindings ||
          partial?.numberOfFixedFindings,
      );
    },

    highlights() {
      if (!this.isCollapsible) {
        return {};
      }

      const highlights = {
        [HIGH]: 0,
        [CRITICAL]: 0,
        other: 0,
      };

      this.reports.forEach((report) => highlightsFromReport(report, highlights));

      return highlights;
    },

    totalNewFindings() {
      return this.reports.reduce((counter, current) => {
        return (
          counter +
          (current.full?.numberOfNewFindings || 0) +
          (current.partial?.numberOfNewFindings || 0)
        );
      }, 0);
    },

    statusIconName() {
      if (this.totalNewFindings > 0) {
        return EXTENSION_ICONS.warning;
      }

      if (this.topLevelErrorMessage) {
        return EXTENSION_ICONS.error;
      }

      return EXTENSION_ICONS.success;
    },

    actionButtons() {
      return [
        {
          href: `${this.mr.pipeline.path}/security`,
          text: this.$options.i18n.viewAllPipelineFindings,
          trackFullReportClicked: true,
        },
      ];
    },

    endpoints() {
      // TODO: check if gl.mrWidgetData can be safely removed after we migrate to the
      // widget extension.
      const items = [
        [this.mr.sastComparisonPathV2, 'SAST'],
        [this.mr.dastComparisonPathV2, 'DAST'],
        [this.mr.secretDetectionComparisonPathV2, 'SECRET_DETECTION'],
        [this.mr.apiFuzzingComparisonPathV2, 'API_FUZZING'],
        [this.mr.coverageFuzzingComparisonPathV2, 'COVERAGE_FUZZING'],
        [this.mr.dependencyScanningComparisonPathV2, 'DEPENDENCY_SCANNING'],
        [this.mr.containerScanningComparisonPathV2, 'CONTAINER_SCANNING'],
      ];

      const endpoints = [];

      items.forEach(([path, reportType]) => {
        if (!path) {
          return;
        }

        const enabledReportsKeyName = convertToCamelCase(reportType.toLowerCase());

        if (this.enabledScans.full[enabledReportsKeyName]) {
          endpoints.push([path.concat('&scan_mode=full'), reportType, { partial: false }]);
        }

        if (this.enabledScans.partial[enabledReportsKeyName]) {
          endpoints.push([path.concat('&scan_mode=partial'), reportType, { partial: true }]);
        }
      });

      return endpoints;
    },

    pipelineIid() {
      return this.modalData.vulnerability.found_by_pipeline?.iid;
    },
    branchRef() {
      return this.mr.sourceBranch;
    },

    shouldRenderMrWidget() {
      if (this.isLoadingEnabledScans) {
        return false;
      }

      return !this.mr.isPipelineActive && this.endpoints.length > 0;
    },

    isLoadingEnabledScans() {
      return this.$apollo.queries.enabledScans?.loading || this.$options.pollingInterval;
    },
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.mr.targetProjectFullPath,
          pipelineIid: this.mr.pipeline?.iid,
        };
      },
      update({ project }) {
        // Return early if pipeline is not defined
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        const scans = project.pipeline;

        // We need to check only one of these because they make the same query in the backend
        const isReady = scans.enabledSecurityScans?.ready === true;

        if (!isReady && !this.$options.pollingInterval) {
          this.initPolling();
        }

        if (isReady && this.$options.pollingInterval) {
          this.$options.pollingInterval.destroy();
          this.$options.pollingInterval = undefined;
        }

        return {
          full: scans.enabledSecurityScans || {},
          partial: scans.enabledPartialSecurityScans || {},
        };
      },
      error() {
        this.topLevelErrorMessage = s__(
          'ciReport|Error while fetching enabled scans. Please try again later.',
        );
      },
      skip() {
        if (!this.glFeatures.vulnerabilityPartialScans) {
          return true;
        }

        return (
          !this.mr.pipeline?.iid ||
          !this.mr.targetProjectFullPath ||
          Boolean(this.mr.pipeline.active)
        );
      },
    },
  },
  beforeDestroy() {
    this.cleanUpResolveWithAiHandlers();

    if (this.$options.pollingInterval) {
      this.$options.pollingInterval.destroy();
    }
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

    handleResolveWithAiSuccess(commentUrl) {
      // the note's id is the hash of the url and also the DOM id which we want to scroll to
      const [, commentNoteId] = commentUrl.split('#');

      const isCommentOnPage = () => document.getElementById(commentNoteId) !== null;
      const closeModalAndScrollToComment = () => {
        this.clearModalData();
        visitUrl(commentUrl);
      };

      if (isCommentOnPage()) {
        closeModalAndScrollToComment();
        return;
      }

      // as a fallback we set a timeout and then manually do a hard page reload
      this.commentNotefallBackTimeout = setTimeout(() => {
        this.cleanUpResolveWithAiHandlers();
        historyPushState(commentUrl);
        window.location.reload();
      }, 3000);

      // observe the DOM and scroll to the comment when it's added
      this.commentMutationObserver = new MutationObserver((mutationList) => {
        for (const mutation of mutationList) {
          // check if the added notes within the mutation contains the comment we're looking for
          if (mutation.addedNodes.length > 0 && isCommentOnPage()) {
            this.cleanUpResolveWithAiHandlers();
            closeModalAndScrollToComment();
            return;
          }
        }
      });

      this.commentMutationObserver.observe(document.getElementById('notes') || document.body, {
        childList: true,
        subtree: true,
      });
    },

    cleanUpResolveWithAiHandlers() {
      if (this.commentNotefallBackTimeout) {
        clearTimeout(this.commentNotefallBackTimeout);
      }
      if (this.commentMutationObserver) {
        this.commentMutationObserver.disconnect();
      }
    },

    updateFindingState(state) {
      this.modalData.vulnerability.state = state;
    },

    handleIsLoading(value) {
      this.isLoading = value;
    },

    fetchCollapsedData() {
      return this.endpoints.map(([path, reportType]) => () => {
        return this.fetchCollapsedDataREST(path, reportType);
      });
    },

    fetchCollapsedDataREST(path, reportType) {
      const isPartial = path.indexOf('scan_mode=partial') > -1;

      const props = {
        reportType,
        reportTypeDescription: reportTypes[reportType],
        numberOfNewFindings: 0,
        numberOfFixedFindings: 0,
        added: [],
        fixed: [],
      };

      return axios
        .get(path)
        .then(({ data, headers = {}, status }) => {
          const added = data.added?.map?.(getFindingWithoutFeedback) || [];
          const fixed = data.fixed?.map?.(getFindingWithoutFeedback) || [];

          // If a single report has 25 findings, it means it potentially has more than 25 findings.
          // Therefore, we display the UI hint in the top-level summary.
          // If there are no reports with 25 findings, but the total sum of all reports is still 25 or more,
          // we won't display the UI hint.
          if (added.length === MAX_NEW_VULNERABILITIES) {
            this.hasAtLeastOneReportWithMaxNewVulnerabilities = true;
          }

          const report = {
            ...props,
            ...data,
            added,
            fixed,
            findings: [...added, ...fixed],
            numberOfNewFindings: added.length,
            numberOfFixedFindings: fixed.length,
            testId: this.$options.testId[reportType],
          };

          const key = isPartial ? 'partial' : 'full';
          this.reportsByScanType[key] = { ...this.reportsByScanType[key], [reportType]: report };

          this.$emit('loaded', added.length);

          return {
            headers,
            status,
            data: report,
          };
        })
        .catch(({ response: { status, headers } }) => {
          const report = { ...props, error: true };

          const key = isPartial ? 'partial' : 'full';
          this.reportsByScanType[key] = { ...this.reportsByScanType[key], [reportType]: report };

          if (status === 400) {
            this.topLevelErrorMessage = s__(
              'ciReport|Parsing schema failed. Check the validity of your .gitlab-ci.yml content.',
            );
          }

          return { headers, status, data: report };
        });
    },

    setModalData(finding) {
      this.modalData = {
        error: null,
        title: finding.name,
        vulnerability: finding,
      };
    },

    clearModalData() {
      this.modalData = null;
    },
  },
  widgetHelpPopover: {
    options: { title: i18n.helpPopoverTitle },
    content: {
      text: i18n.helpPopoverContent,
      learnMorePath: helpPagePath('user/application_security/detect/security_scanning_results', {
        anchor: 'merge-request-security-widget',
      }),
    },
  },
  testId: {
    SAST: 'sast-scan-report',
    DAST: 'dast-scan-report',
    DEPENDENCY_SCANNING: 'dependency-scan-report',
    SECRET_DETECTION: 'secret-detection-report',
    CONTAINER_SCANNING: 'container-scan-report',
    COVERAGE_FUZZING: 'coverage-fuzzing-report',
    API_FUZZING: 'api-fuzzing-report',
  },
  pollingInterval: undefined,
};
</script>

<template>
  <mr-widget
    v-if="shouldRenderMrWidget"
    :error-text="topLevelErrorMessage || $options.i18n.error"
    :has-error="Boolean(topLevelErrorMessage)"
    :fetch-collapsed-data="fetchCollapsedData"
    :status-icon-name="statusIconName"
    :widget-name="$options.name"
    :is-collapsible="isCollapsible"
    :help-popover="$options.widgetHelpPopover"
    :action-buttons="actionButtons"
    :label="$options.i18n.label"
    path="security-reports"
    multi-polling
    data-testid="vulnerability-report-grouped"
    @is-loading="handleIsLoading"
  >
    <template #summary>
      <summary-text
        :total-new-vulnerabilities="totalNewFindings"
        :is-loading="isLoading"
        :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
      />
      <summary-highlights v-if="!isLoading && totalNewFindings > 0" :highlights="highlights" />
    </template>
    <template #content>
      <vulnerability-finding-modal
        v-if="modalData"
        :finding-uuid="modalData.vulnerability.uuid"
        :pipeline-iid="pipelineIid"
        :branch-ref="branchRef"
        :project-full-path="mr.targetProjectFullPath"
        :source-project-full-path="mr.sourceProjectFullPath"
        :show-ai-resolution="true"
        :merge-request-id="mr.id"
        data-testid="vulnerability-finding-modal"
        @hidden="clearModalData"
        @dismissed="updateFindingState('dismissed')"
        @detected="updateFindingState('detected')"
        @resolveWithAiSuccess="handleResolveWithAiSuccess"
      />
      <security-training-promo-widget :security-configuration-path="mr.securityConfigurationPath" />
      <report-details
        v-for="report in reports"
        :key="report.reportType"
        :widget-name="$options.name"
        :report="report"
        :mr="mr"
        @modal-data="setModalData"
      />
    </template>
  </mr-widget>
  <!--
    We must fetch enabled scans before mounting the MR widget because the widget
    immediately calls `fetchCollapsedData` on mount. Since `fetchCollapsedData`
    needs the enabled scans result to determine which endpoints to query, we delay
    mounting until the enabled scans have been fetched.

    In order to display the loading state in the meantime, we mount this
    <mr-widget> component instead of the one above.
    -->
  <mr-widget
    v-else-if="isLoadingEnabledScans"
    key="mr-widget-loading"
    :is-collapsible="false"
    :widget-name="$options.name"
    loading-state="collapsed"
    data-testid="vulnerability-report-grouped"
  >
    <template #summary>
      <summary-text is-loading :total-new-vulnerabilities="0" />
    </template>
  </mr-widget>
</template>
