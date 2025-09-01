<script>
import { GlBadge, GlButton, GlIcon, GlLink, GlPopover } from '@gitlab/ui';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { s__ } from '~/locale';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DynamicScroller, DynamicScrollerItem } from 'vendor/vue-virtual-scroller';
import SummaryText from './summary_text.vue';
import { i18n, popovers } from './i18n';
import { highlightsFromReport } from './utils';

export default {
  SEVERITY_LEVELS,
  i18n,
  components: {
    MrWidgetRow,
    GlBadge,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
    DynamicScroller,
    DynamicScrollerItem,
    SummaryText,
    SummaryHighlights,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    report: {
      type: Object,
      required: true,
    },
    mr: {
      type: Object,
      required: true,
    },
    widgetName: {
      type: String,
      required: true,
    },
  },
  computed: {
    helpPopovers() {
      return {
        SAST: {
          options: { title: popovers.SAST_TITLE },
          content: { text: popovers.SAST_TEXT, learnMorePath: this.mr.sastHelp },
        },
        DAST: {
          options: { title: popovers.DAST_TITLE },
          content: { text: popovers.DAST_TEXT, learnMorePath: this.mr.dastHelp },
        },
        SECRET_DETECTION: {
          options: { title: popovers.SECRET_DETECTION_TITLE },
          content: {
            text: popovers.SECRET_DETECTION_TEXT,
            learnMorePath: this.mr.secretDetectionHelp,
          },
        },
        CONTAINER_SCANNING: {
          options: { title: popovers.CONTAINER_SCANNING_TITLE },
          content: {
            text: popovers.CONTAINER_SCANNING_TEXT,
            learnMorePath: this.mr.containerScanningHelp,
          },
        },
        DEPENDENCY_SCANNING: {
          options: { title: popovers.DEPENDENCY_SCANNING_TITLE },
          content: {
            text: popovers.DEPENDENCY_SCANNING_TEXT,
            learnMorePath: this.mr.dependencyScanningHelp,
          },
        },
        API_FUZZING: {
          options: { title: popovers.API_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.apiFuzzingHelp,
          },
        },
        COVERAGE_FUZZING: {
          options: { title: popovers.COVERAGE_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.coverageFuzzingHelp,
          },
        },
      };
    },
  },
  methods: {
    statusIconNameReportType(report) {
      if (report.numberOfNewFindings > 0 || report.error) {
        return EXTENSION_ICONS.warning;
      }

      return EXTENSION_ICONS.success;
    },

    statusIconNameVulnerability(vuln) {
      return EXTENSION_ICONS[`severity${capitalizeFirstCharacter(vuln.severity)}`];
    },

    isDismissed(vuln) {
      return vuln.state === 'dismissed';
    },

    setModalData(finding) {
      this.$emit('modal-data', finding);
    },

    isAiResolvable(vuln) {
      return vuln.ai_resolution_enabled && this.glAbilities.resolveVulnerabilityWithAi;
    },

    getAiResolvableBadgeId(uuid) {
      return `ai-resolvable-badge-${uuid}`;
    },

    highlightsFromReport,
  },
  aiResolutionHelpPopOver: {
    text: s__(
      'ciReport|GitLab Duo Vulnerability Resolution, an AI feature, can suggest a possible fix.',
    ),
    learnMorePath: helpPagePath('user/application_security/vulnerabilities/_index', {
      anchor: 'vulnerability-resolution-in-a-merge-request',
    }),
  },
};
</script>

<template>
  <mr-widget-row
    :widget-name="widgetName"
    :level="2"
    :status-icon-name="statusIconNameReportType(report)"
    :help-popover="helpPopovers[report.reportType]"
    :data-testid="`report-${report.reportType}`"
  >
    <template #header>
      <div>
        <summary-text
          :total-new-vulnerabilities="report.numberOfNewFindings"
          :is-loading="false"
          :error="report.error"
          :scanner="report.reportTypeDescription"
          :data-testid="`${report.testId}`"
          show-at-least-hint
        />
        <summary-highlights
          v-if="report.numberOfNewFindings > 0"
          :highlights="highlightsFromReport(report)"
        />
      </div>
    </template>
    <template #body>
      <div
        v-if="report.numberOfNewFindings || report.numberOfFixedFindings"
        class="gl-mt-2 gl-w-full"
      >
        <dynamic-scroller
          :items="report.findings"
          :min-item-size="32"
          :style="{ maxHeight: '170px' }"
          data-testid="dynamic-content-scroller"
          key-field="uuid"
          class="gl-pr-5"
        >
          <template #default="{ item: vuln, active, index }">
            <dynamic-scroller-item :item="vuln" :active="active">
              <strong
                v-if="report.numberOfNewFindings > 0 && index === 0"
                data-testid="new-findings-title"
                class="gl-mt-2 gl-block"
                >{{ $options.i18n.new }}</strong
              >
              <strong
                v-if="report.numberOfFixedFindings > 0 && report.numberOfNewFindings === index"
                data-testid="fixed-findings-title"
                class="gl-mt-2 gl-block"
                >{{ $options.i18n.fixed }}</strong
              >
              <mr-widget-row
                :key="vuln.uuid"
                :level="3"
                :widget-name="widgetName"
                :status-icon-name="statusIconNameVulnerability(vuln)"
                class="gl-mt-2"
              >
                <template #body>
                  {{ $options.SEVERITY_LEVELS[vuln.severity] }}
                  <gl-button
                    variant="link"
                    class="gl-ml-2 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
                    @click="setModalData(vuln)"
                    >{{ vuln.name }}
                  </gl-button>
                  <gl-badge v-if="isDismissed(vuln)" class="gl-ml-3"
                    >{{ $options.i18n.dismissed }}
                  </gl-badge>
                  <template v-if="isAiResolvable(vuln)">
                    <gl-badge
                      :id="getAiResolvableBadgeId(vuln.uuid)"
                      variant="info"
                      class="gl-ml-3"
                      data-testid="ai-resolvable-badge"
                    >
                      <gl-icon :size="12" name="tanuki-ai" />
                    </gl-badge>
                    <gl-popover
                      trigger="hover focus"
                      placement="top"
                      boundary="viewport"
                      :target="getAiResolvableBadgeId(vuln.uuid)"
                      :data-testid="`ai-resolvable-badge-popover-${vuln.uuid}`"
                    >
                      {{ $options.aiResolutionHelpPopOver.text }}
                      <gl-link :href="$options.aiResolutionHelpPopOver.learnMorePath"
                        >{{ __('Learn more') }}
                      </gl-link>
                    </gl-popover>
                  </template>
                </template>
              </mr-widget-row>
            </dynamic-scroller-item>
          </template>
        </dynamic-scroller>
      </div>
    </template>
  </mr-widget-row>
</template>
