<script>
import { GlTooltip, GlIcon, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { __, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { SEVERITY_CLASS_NAME_MAP, SEVERITY_TOOLTIP_TITLE_MAP } from './constants';

export default {
  name: 'SeverityBadge',
  components: {
    TimeAgoTooltip,
    GlIcon,
    GlSprintf,
    GlTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    severity: {
      type: String,
      required: true,
    },
    severityOverrides: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    showSeverityOverrides: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    severityDetailsTooltip: __(
      '%{user_name} changed the severity from %{original_severity} to %{new_severity} %{changed_at}.',
    ),
  },
  data() {
    return {
      tooltipId: uniqueId('tooltip-severity-changed-'),
    };
  },
  computed: {
    getLastSeverityOverride() {
      return Object.keys(this.severityOverrides).length > 0 &&
        this.severityOverrides.nodes.length > 0
        ? this.severityOverrides.nodes.at(-1)
        : {};
    },
    shouldShowSeverityOverrides() {
      return this.showSeverityOverrides && Object.keys(this.getLastSeverityOverride).length > 0;
    },
    severityOverridesObj() {
      if (this.shouldShowSeverityOverrides) {
        return {
          ...this.getLastSeverityOverride,
          author: this.getLastSeverityOverride.author?.name,
          createdAt: this.getLastSeverityOverride.createdAt,
          originalSeverity: this.getLastSeverityOverride.originalSeverity?.toLowerCase(),
          newSeverity: this.getLastSeverityOverride.newSeverity?.toLowerCase(),
        };
      }
      return {};
    },
    hasSeverityBadge() {
      return Object.keys(SEVERITY_CLASS_NAME_MAP).includes(this.severityKey);
    },
    severityKey() {
      return this.severity?.toLowerCase();
    },
    className() {
      return SEVERITY_CLASS_NAME_MAP[this.severityKey];
    },
    iconName() {
      return `severity-${this.severityKey}`;
    },
    severityTitle() {
      return SEVERITY_LEVELS[this.severityKey] || this.severity;
    },
    tooltipTitle() {
      return SEVERITY_TOOLTIP_TITLE_MAP[this.severityKey];
    },
    severityOverridesTooltipChangesSection() {
      return sprintf(this.$options.i18n.severityDetailsTooltip);
    },
  },
};
</script>

<template>
  <div
    v-if="hasSeverityBadge"
    class="severity-badge gl-whitespace-nowrap gl-text-default sm:gl-text-left"
  >
    <span :class="className"
      ><gl-icon v-gl-tooltip="tooltipTitle" :name="iconName" :size="12" class="gl-mr-3"
    /></span>
    {{ severityTitle }}

    <span
      v-if="shouldShowSeverityOverrides"
      class="gl-text-orange-300"
      data-testid="severity-override"
    >
      <gl-icon :id="tooltipId" v-gl-tooltip name="file-modified" class="gl-ml-3" :size="16" />
      <gl-tooltip placement="top" :target="tooltipId">
        <gl-sprintf :message="severityOverridesTooltipChangesSection">
          <template #user_name>
            <strong>{{ severityOverridesObj.author }}</strong>
          </template>
          <template #original_severity>
            <strong>{{ severityOverridesObj.originalSeverity }}</strong>
          </template>
          <template #new_severity>
            <strong>{{ severityOverridesObj.newSeverity }}</strong>
          </template>
          <template #changed_at>
            <time-ago-tooltip ref="timeAgo" :time="severityOverridesObj.createdAt" />
          </template>
        </gl-sprintf>
        <br />
      </gl-tooltip>
    </span>
  </div>
</template>
