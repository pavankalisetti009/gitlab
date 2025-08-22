<script>
import { GlIcon, GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import LifecycleNameForm from './lifecycle_name_form.vue';

export default {
  components: {
    GlIcon,
    WorkItemStatusBadge,
    LifecycleNameForm,
    GlButton,
    GlCollapsibleListbox,
  },
  props: {
    lifecycle: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
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
    showUsageSection: {
      type: Boolean,
      required: false,
      default: false,
    },
    showNotInUseSection: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveLifecycleCta: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      cardHover: false,
    };
  },
  computed: {
    lifecycleId() {
      return getIdFromGraphQLId(this.lifecycle.id);
    },
    items() {
      return (this.lifecycle.workItemTypes || []).map(({ name }) => ({ text: name, value: name }));
    },
  },
};
</script>
<template>
  <div
    :key="lifecycle.id"
    class="gl-border gl-rounded-lg gl-bg-white gl-px-4 gl-pt-4"
    data-testid="lifecycle-detail"
  >
    <div class="gl-mb-3" @mouseenter="cardHover = true" @mouseleave="cardHover = false">
      <span v-if="showRadioSelection" :data-testid="`lifecycle-${lifecycleId}-select`">
        <slot name="radio-selection"></slot>
      </span>

      <lifecycle-name-form
        v-else
        :lifecycle="lifecycle"
        :is-default-lifecycle="isDefaultLifecycle"
        :full-path="fullPath"
        :card-hover="cardHover"
      />

      <div class="gl-mx-auto gl-my-3 gl-flex gl-flex-wrap gl-gap-3">
        <div v-for="status in lifecycle.statuses" :key="status.id" class="gl-max-w-20">
          <work-item-status-badge :key="status.id" :item="status" />
        </div>
      </div>

      <slot name="detail-footer"></slot>
    </div>

    <div
      v-if="lifecycle.workItemTypes.length && showUsageSection"
      :data-testid="`lifecycle-${lifecycleId}-usage`"
      class="-gl-mx-4 gl-flex gl-flex-wrap gl-items-center gl-gap-3 gl-rounded-bl-lg gl-rounded-br-lg gl-border-t-1 gl-border-gray-400 gl-bg-strong gl-px-4 gl-py-2"
    >
      <span class="gl-text-sm gl-text-subtle">{{ s__('WorkItem|Usage:') }}</span>
      <span
        v-for="workItemType in lifecycle.workItemTypes"
        :key="workItemType.id"
        class="gl-flex gl-items-center gl-gap-1 gl-text-sm"
        data-testid="work-item-type-name"
      >
        <gl-icon :name="workItemType.iconName" :size="14" />
        <span>{{ workItemType.name }}</span>
      </span>

      <gl-collapsible-listbox
        :items="items"
        :header-text="s__('WorkItem|Select type to change')"
        :toggle-text="s__('WorkItem|Change lifecycle')"
        category="secondary"
        size="small"
      />
    </div>

    <div
      v-else-if="showNotInUseSection"
      class="gl-border-warning-400 -gl-mx-4 gl-flex gl-items-center gl-gap-3 gl-rounded-bl-lg gl-rounded-br-lg gl-border-t-1 gl-bg-feedback-warning gl-px-4 gl-py-2"
      :class="{
        'gl-py-3': !showRemoveLifecycleCta,
      }"
    >
      <gl-icon name="warning" :size="14" class="gl-text-orange-700" />
      <span class="gl-text-sm gl-text-orange-700">
        {{ s__('WorkItem|Not in use') }}
      </span>

      <gl-button v-if="showRemoveLifecycleCta" size="small">{{
        s__('WorkItem|Remove lifecycle')
      }}</gl-button>
    </div>
  </div>
</template>
