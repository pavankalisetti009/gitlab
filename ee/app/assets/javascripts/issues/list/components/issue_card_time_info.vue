<script>
import { GlIcon } from '@gitlab/ui';
import IssueCardTimeInfo from '~/issues/list/components/issue_card_time_info.vue';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import { findHealthStatusWidget, findWeightWidget, findIterationWidget } from '~/work_items/utils';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

export default {
  components: {
    IssueCardTimeInfo,
    IssueHealthStatus,
    WorkItemAttribute,
    GlIcon,
    WorkItemIterationAttribute,
  },
  inject: ['hasIssuableHealthStatusFeature', 'hasIssueWeightsFeature', 'hasIterationsFeature'],
  props: {
    issue: {
      type: Object,
      required: true,
    },
    isWorkItemList: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    healthStatus() {
      return this.issue.healthStatus || findHealthStatusWidget(this.issue)?.healthStatus;
    },
    showHealthStatus() {
      return this.hasIssuableHealthStatusFeature && this.healthStatus && !this.isWorkItemList;
    },
    weight() {
      return this.issue.weight || findWeightWidget(this.issue)?.weight;
    },
    showWeight() {
      return this.hasIssueWeightsFeature && this.weight != null;
    },
    iteration() {
      return this.hasIterationsFeature && findIterationWidget(this.issue)?.iteration;
    },
  },
};
</script>

<template>
  <issue-card-time-info :issue="issue">
    <template #weight>
      <work-item-attribute
        v-if="showWeight"
        anchor-id="issuable-weight-content"
        data-testid="weight-attribute"
        :title="`${weight}`"
        title-component-class="issuable-weight gl-mr-3"
        :tooltip-text="__('Weight')"
        tooltip-placement="top"
      >
        <template #icon>
          <gl-icon name="weight" :size="12" />
        </template>
      </work-item-attribute>
    </template>
    <issue-health-status v-if="showHealthStatus" :health-status="healthStatus" />
    <template #iteration>
      <work-item-iteration-attribute v-if="iteration" :iteration="iteration" />
    </template>
  </issue-card-time-info>
</template>
