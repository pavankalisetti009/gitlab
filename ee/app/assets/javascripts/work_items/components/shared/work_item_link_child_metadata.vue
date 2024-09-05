<script>
import { GlIcon, GlTooltip, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import WorkItemLinkChildMetadata from '~/work_items/components/shared/work_item_link_child_metadata.vue';
import {
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_PROGRESS,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_ITERATION,
  WIDGET_TYPE_START_AND_DUE_DATE,
  WORK_ITEM_TYPE_VALUE_EPIC,
} from '~/work_items/constants';
import { formatDate, humanTimeframe } from '~/lib/utils/datetime_utility';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { getIterationPeriod } from 'ee/iterations/utils';

export default {
  name: 'WorkItemLinkChildEE',
  components: {
    GlIcon,
    GlTooltip,
    IssueHealthStatus,
    WorkItemLinkChildMetadata,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  props: {
    iid: {
      type: String,
      required: true,
    },
    reference: {
      type: String,
      required: true,
    },
    metadataWidgets: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    showWeight: {
      type: Boolean,
      required: false,
      default: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  computed: {
    progress() {
      return this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.progress;
    },
    progressLastUpdatedAtInWords() {
      return this.getTimestampInWords(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.updatedAt);
    },
    progressLastUpdatedAtTimestamp() {
      return this.getTimestamp(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.updatedAt);
    },
    healthStatus() {
      return this.metadataWidgets[WIDGET_TYPE_HEALTH_STATUS]?.healthStatus;
    },
    hasProgress() {
      return Number.isInteger(this.progress);
    },
    isWeightRollup() {
      return this.metadataWidgets[WIDGET_TYPE_WEIGHT]?.widgetDefinition?.rollUp;
    },
    weight() {
      return this.metadataWidgets[WIDGET_TYPE_WEIGHT]?.weight;
    },
    rolledUpWeight() {
      return this.metadataWidgets[WIDGET_TYPE_WEIGHT]?.rolledUpWeight;
    },
    workItemWeight() {
      return this.isWeightRollup ? this.rolledUpWeight : this.weight;
    },
    shouldShowWeight() {
      return this.showWeight && Boolean(this.workItemWeight);
    },
    iteration() {
      return this.metadataWidgets[WIDGET_TYPE_ITERATION]?.iteration;
    },
    iterationTitle() {
      return this.metadataWidgets[WIDGET_TYPE_ITERATION]?.iteration?.title;
    },
    iterationCadenceTitle() {
      return this.metadataWidgets[WIDGET_TYPE_ITERATION]?.iteration?.iterationCadence?.title;
    },
    iterationPeriod() {
      return getIterationPeriod(this.iteration);
    },
    startDate() {
      return this.metadataWidgets[WIDGET_TYPE_START_AND_DUE_DATE]?.startDate;
    },
    dueDate() {
      return this.metadataWidgets[WIDGET_TYPE_START_AND_DUE_DATE]?.dueDate;
    },
    showDate() {
      return this.startDate || this.dueDate;
    },
    workItemTimeframe() {
      return humanTimeframe(this.startDate, this.dueDate);
    },
    weightTooltip() {
      return this.workItemType === WORK_ITEM_TYPE_VALUE_EPIC ? __('Issue weight') : __('Weight');
    },
  },
  methods: {
    getTimestamp(rawTimestamp) {
      return rawTimestamp ? formatDate(new Date(rawTimestamp)) : '';
    },
    getTimestampInWords(rawTimestamp) {
      return rawTimestamp ? this.timeFormatted(rawTimestamp) : '';
    },
  },
};
</script>

<template>
  <work-item-link-child-metadata
    :iid="iid"
    :reference="reference"
    :metadata-widgets="metadataWidgets"
  >
    <template #left-metadata>
      <div
        v-if="shouldShowWeight"
        ref="weightData"
        data-testid="item-weight"
        class="gl-flex gl-cursor-help gl-items-center gl-gap-2"
      >
        <gl-icon name="weight" />
        <span data-testid="weight-value">{{ workItemWeight }}</span>
        <gl-tooltip :target="() => $refs.weightData">
          <span data-testid="weight-tooltip" class="gl-font-bold">
            {{ weightTooltip }}
          </span>
        </gl-tooltip>
      </div>
      <div
        v-if="iteration"
        ref="iterationData"
        data-testid="item-iteration"
        class="gl-flex gl-cursor-help gl-items-center gl-gap-2"
      >
        <gl-icon name="iteration" />
        <span data-testid="iteration-value">{{ iterationPeriod }}</span>
        <gl-tooltip :target="() => $refs.iterationData">
          <div data-testid="iteration-title" class="gl-font-bold">
            {{ __('Iteration') }}
          </div>
          <div v-if="iterationCadenceTitle" data-testid="iteration-cadence-text">
            {{ iterationCadenceTitle }}
          </div>
          <div v-if="iterationPeriod" data-testid="iteration-period-text">
            {{ iterationPeriod }}
          </div>
          <div v-if="iterationTitle" data-testid="iteration-title-text">
            {{ iterationTitle }}
          </div>
        </gl-tooltip>
      </div>
      <div
        v-if="showDate"
        ref="datesData"
        data-testid="item-dates"
        class="gl-flex gl-min-w-10 gl-max-w-26 gl-cursor-help gl-flex-wrap gl-gap-2"
      >
        <gl-icon name="calendar" />
        <span data-testid="dates-value">{{ workItemTimeframe }}</span>
        <gl-tooltip :target="() => $refs.datesData">
          <div class="gl-font-bold">
            {{ __('Dates') }}
          </div>
        </gl-tooltip>
      </div>
      <div
        v-if="hasProgress"
        ref="progressTooltip"
        class="gl-flex gl-min-w-10 gl-max-w-26 gl-cursor-help gl-items-center gl-justify-start gl-gap-2 gl-leading-normal"
        data-testid="item-progress"
      >
        <gl-icon name="progress" />
        <span data-testid="progressValue">{{ progress }}%</span>
        <gl-tooltip :target="() => $refs.progressTooltip">
          <div data-testid="progressTitle" class="gl-font-bold">
            {{ __('Progress') }}
          </div>
          <div v-if="progressLastUpdatedAtInWords" class="gl-text-tertiary">
            <span data-testid="progressText" class="gl-font-bold">
              {{ __('Last updated') }}
            </span>
            <span data-testid="lastUpdatedInWords">{{ progressLastUpdatedAtInWords }}</span>
            <div data-testid="lastUpdatedTimestamp">{{ progressLastUpdatedAtTimestamp }}</div>
          </div>
        </gl-tooltip>
      </div>
    </template>
    <template #right-metadata>
      <issue-health-status v-if="healthStatus" :health-status="healthStatus" />
    </template>
  </work-item-link-child-metadata>
</template>
