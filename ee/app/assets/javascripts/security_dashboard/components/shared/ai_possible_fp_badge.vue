<script>
import { GlBadge, GlIcon, GlPopover, GlProgressBar, GlButton, GlTruncateText } from '@gitlab/ui';
import {
  VULNERABILITY_STATE_OBJECTS,
  CONFIDENCE_SCORES,
  AI_FP_DISMISSAL_COMMENT,
} from 'ee/vulnerabilities/constants';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';

export const VULNERABILITY_UNTRIAGED_STATUS = VULNERABILITY_STATE_OBJECTS.detected.searchParamValue;

export default {
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlPopover,
    GlProgressBar,
    GlTruncateText,
  },
  inject: {
    vulnerabilitiesQuery: {
      default: null,
    },
  },
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
    canAdminVulnerability: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    flag() {
      return this.vulnerability.latestFlag;
    },
    isLikelyFalsePositive() {
      return this.flag.confidenceScore >= CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE;
    },
    shouldRenderBadge() {
      return this.flag?.confidenceScore > CONFIDENCE_SCORES.MINIMAL;
    },
    badgeText() {
      return this.isLikelyFalsePositive
        ? this.$options.i18n.badgeTextLikelyFP
        : this.$options.i18n.badgeTextPossibleFP;
    },
    badgeVariant() {
      return this.isLikelyFalsePositive ? 'success' : 'warning';
    },
    confidencePercentage() {
      return Math.round(this.flag.confidenceScore * 100);
    },
    canDismissVulnerability() {
      return (
        this.canAdminVulnerability && this.vulnerability.state === VULNERABILITY_UNTRIAGED_STATUS
      );
    },
  },
  methods: {
    removeFlag() {
      this.$apollo
        .mutate({
          mutation: VULNERABILITY_STATE_OBJECTS.dismissed.mutation,
          variables: {
            id: this.vulnerability.id,
            dismissalReason: 'FALSE_POSITIVE',
            comment: AI_FP_DISMISSAL_COMMENT,
          },
          refetchQueries: [this.vulnerabilitiesQuery],
        })
        .catch((error) => {
          createAlert({
            message: s__('Vulnerability|Something went wrong while dismissing the vulnerability.'),
            captureError: true,
            error,
          });
        });
    },
  },
  i18n: {
    badgeTextPossibleFP: s__('Vulnerability|Possible FP'),
    badgeTextLikelyFP: s__('Vulnerability|Likely FP'),
    aiConfidenceScore: s__('Vulnerability|AI Confidence Score'),
    why: s__('Vulnerability|Why it is likely a false positive'),
    removeFlag: s__('Vulnerability|Remove False Positive Flag'),
  },
};
</script>

<template>
  <gl-badge v-if="shouldRenderBadge" ref="badge" :variant="badgeVariant" size="sm">
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    <span data-testid="ai-fix-in-progress-b"> {{ badgeText }}</span>
    <gl-popover
      :target="() => $refs.badge.$el"
      placement="left"
      show-close-button
      :css-classes="['gl-max-w-62']"
    >
      <template #title>{{ vulnerability.title }}</template>
      <div class="gl-mt-2 gl-flex gl-items-center gl-gap-3 gl-font-bold">
        {{ $options.i18n.aiConfidenceScore }}:
        <gl-progress-bar
          :value="confidencePercentage"
          class="gl-h-3 gl-w-15"
          :variant="badgeVariant"
        />
        {{ confidencePercentage }}%
      </div>
      <div v-if="flag.description" class="gl-mt-3">
        <h4 class="gl-text-base gl-font-bold">{{ $options.i18n.why }}</h4>
        <gl-truncate-text :lines="5" class="gl-whitespace-pre-wrap">{{
          flag.description
        }}</gl-truncate-text>
      </div>
      <gl-button v-if="canDismissVulnerability" class="gl-mt-5" variant="link" @click="removeFlag">
        {{ $options.i18n.removeFlag }}
      </gl-button>
    </gl-popover>
  </gl-badge>
</template>
