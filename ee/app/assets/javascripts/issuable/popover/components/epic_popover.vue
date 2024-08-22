<script>
import { GlIcon, GlPopover, GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { humanTimeframe } from '~/lib/utils/datetime/date_format_utility';
import StatusBadge from '~/issuable/components/status_badge.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { TYPE_EPIC } from '~/issues/constants';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';

import query from '../queries/epic.query.graphql';

export default {
  TYPE_EPIC,
  components: {
    GlIcon,
    GlPopover,
    GlSkeletonLoader,
    StatusBadge,
    WorkItemTypeIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  props: {
    target: {
      type: HTMLAnchorElement,
      required: true,
    },
    namespacePath: {
      type: String,
      required: true,
    },
    iid: {
      type: String,
      required: true,
    },
    cachedTitle: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      epic: {},
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.epic.loading;
    },
    formattedTime() {
      return this.timeFormatted(this.epic.createdAt);
    },
    title() {
      return this.epic?.title || this.cachedTitle;
    },
    showDetails() {
      return Object.keys(this.epic).length > 0;
    },
    showTimeframe() {
      return !this.loading && Boolean(this.epicTimeframe);
    },
    referenceFull() {
      return `${this.namespacePath}&${this.iid}`;
    },
    epicTimeframe() {
      return humanTimeframe(this.epic.startDate, this.epic.dueDate);
    },
  },
  apollo: {
    epic: {
      query,
      variables() {
        const { namespacePath, iid } = this;

        return {
          fullPath: namespacePath,
          iid,
        };
      },
      update: (data) => data.group.epic,
    },
  },
};
</script>

<template>
  <gl-popover :target="target" boundary="viewport" placement="top" show>
    <gl-skeleton-loader v-if="loading" :height="15">
      <rect width="250" height="15" rx="4" />
    </gl-skeleton-loader>
    <div v-else-if="showDetails" class="gl-flex gl-items-center gl-gap-2">
      <status-badge :issuable-type="$options.TYPE_EPIC" :state="epic.state" />
      <gl-icon
        v-if="epic.confidential"
        v-gl-tooltip
        name="eye-slash"
        :title="__('Confidential')"
        class="gl-text-orange-500"
        :aria-label="__('Confidential')"
        data-testid="confidential-icon"
      />
      <span class="gl-text-secondary" data-testid="created-at">
        {{ __('Opened') }} <time :datetime="epic.createdAt">{{ formattedTime }}</time>
      </span>
    </div>
    <h5 v-if="!loading" class="gl-my-3">{{ title }}</h5>
    <div>
      <work-item-type-icon work-item-type="epic" />
      <span class="gl-text-secondary">{{ referenceFull }}</span>
    </div>
    <div
      v-if="showTimeframe"
      class="gl-mt-2 gl-flex gl-text-secondary"
      data-testid="epic-timeframe"
    >
      <gl-icon name="calendar" />
      <span class="gl-ml-2">{{ epicTimeframe }}</span>
    </div>
  </gl-popover>
</template>
