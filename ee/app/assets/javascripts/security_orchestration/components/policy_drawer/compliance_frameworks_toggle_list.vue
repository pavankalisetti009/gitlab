<script>
import { GlLabel } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import {
  COMPLIANCE_FRAMEWORKS_DESCRIPTION,
  COMPLIANCE_FRAMEWORKS_DESCRIPTION_NO_PROJECTS,
} from 'ee/security_orchestration/components/policy_drawer/constants';

export default {
  name: 'ComplianceFrameworksToggleList',
  components: {
    GlLabel,
  },
  props: {
    complianceFrameworks: {
      type: Array,
      required: false,
      default: () => [],
    },
    labelsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    hasHiddenLabels() {
      const { length } = this.complianceFrameworks;

      return length > 0 && this.sanitizedLabelsTo > 0 && this.sanitizedLabelsTo < length;
    },
    hiddenLabelsText() {
      return sprintf(__('+ %{hiddenLabelsLength} more'), {
        hiddenLabelsLength: this.hiddenLabelsLength,
      });
    },
    hiddenLabelsLength() {
      const difference = this.complianceFrameworks.length - this.sanitizedLabelsTo;
      return Math.max(difference, 0);
    },
    complianceFrameworksFormatted() {
      return this.sanitizedLabelsTo === 0
        ? this.complianceFrameworks
        : this.complianceFrameworks.slice(0, this.sanitizedLabelsTo);
    },
    sanitizedLabelsTo() {
      return Number.isNaN(this.labelsToShow) ? 0 : Math.ceil(this.labelsToShow);
    },
    header() {
      if (this.projectsLength === 0) {
        return COMPLIANCE_FRAMEWORKS_DESCRIPTION_NO_PROJECTS;
      }

      return COMPLIANCE_FRAMEWORKS_DESCRIPTION(this.projectsLength);
    },
    projectsLength() {
      const allProjectsOfComplianceFrameworks = this.complianceFrameworks
        ?.flatMap(({ projects = {} }) => projects?.nodes?.map(({ id }) => id))
        .filter(Boolean);

      return Array.from(new Set(allProjectsOfComplianceFrameworks))?.length || 0;
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-2" data-testid="compliance-frameworks-header">
      {{ header }}
    </p>

    <div class="gl-flex gl-flex-wrap gl-gap-3">
      <gl-label
        v-for="item in complianceFrameworksFormatted"
        :key="item.id"
        :background-color="item.color"
        :description="item.description"
        :title="item.name"
      />
    </div>

    <p v-if="hasHiddenLabels" data-testid="hidden-labels-text" class="gl-m-0 gl-mt-3">
      {{ hiddenLabelsText }}
    </p>
  </div>
</template>
