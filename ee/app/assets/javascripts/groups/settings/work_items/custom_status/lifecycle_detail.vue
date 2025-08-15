<script>
import { GlIcon } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';

export default {
  components: {
    GlIcon,
    WorkItemStatusBadge,
  },
  props: {
    lifecycle: {
      type: Object,
      required: true,
    },
    isDefaultLifecycle: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRadioSelection: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    lifecycleId() {
      return getIdFromGraphQLId(this.lifecycle.id);
    },
  },
};
</script>
<template>
  <div
    :key="lifecycle.id"
    class="gl-border gl-rounded-lg gl-bg-white gl-px-4 gl-py-4"
    data-testid="lifecycle-detail"
  >
    <span v-if="showRadioSelection" data-testid="lifecycle-select">
      <slot name="radio-selection"></slot>
    </span>

    <h5 v-else>
      {{ isDefaultLifecycle ? s__('WorkItem|Default statuses') : lifecycle.name }}
    </h5>

    <div class="gl-mx-auto gl-my-3 gl-flex gl-flex-wrap gl-gap-3">
      <div v-for="status in lifecycle.statuses" :key="status.id" class="gl-max-w-20">
        <work-item-status-badge :key="status.id" :item="status" />
      </div>
    </div>

    <div
      v-if="lifecycle.workItemTypes.length"
      :data-testid="`lifecycle-${lifecycleId}-usage`"
      class="gl-mb-3 gl-flex gl-gap-3 gl-border-t-1 gl-border-gray-400"
    >
      <span>{{ s__('WorkItem|Usage') }}</span>
      <span
        v-for="workItemType in lifecycle.workItemTypes"
        :key="workItemType.id"
        class="gl-text-subtle"
        data-testid="work-item-type-name"
      >
        <gl-icon :name="workItemType.iconName" />
        <span>{{ workItemType.name }}</span>
      </span>
    </div>
  </div>
</template>
