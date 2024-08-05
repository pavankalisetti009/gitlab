<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import ApprovalsCountCe from '~/merge_request_dashboard/components/approval_count.vue';

export default {
  components: {
    GlBadge,
    ApprovalsCountCe,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    mergeRequest: {
      type: Object,
      required: true,
    },
  },
  computed: {
    approvalText() {
      return `${this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft}/${
        this.mergeRequest.approvalsRequired
      }`;
    },
    tooltipTitle() {
      return sprintf(__('Required approvals (%{approvals_given} of %{required} given)'), {
        approvals_given: this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft,
        required: this.mergeRequest.approvalsRequired,
      });
    },
    badgeVariant() {
      return this.mergeRequest.approved ? 'success' : 'neutral';
    },
    badgeIcon() {
      if (this.mergeRequest.approved) return 'check-circle';

      return this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft > 0
        ? 'check-circle-dashed'
        : 'dash-circle';
    },
  },
};
</script>

<template>
  <gl-badge
    v-if="mergeRequest.approvalsRequired"
    v-gl-tooltip.viewport.top="tooltipTitle"
    :icon="badgeIcon"
    :variant="badgeVariant"
  >
    {{ approvalText }}
  </gl-badge>
  <approvals-count-ce v-else :merge-request="mergeRequest" />
</template>
