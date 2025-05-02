<script>
import { GlTooltipDirective } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WorkItemLinkChildContents from '~/work_items/components/shared/work_item_link_child_contents.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';

export default {
  name: 'WorkItemLinkChildContentsEE',
  components: {
    WorkItemLinkChildContents,
    WorkItemStatusBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    childItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    workItemFullPath: {
      type: String,
      required: true,
    },
    showLabels: {
      type: Boolean,
      required: false,
      default: true,
    },
    showWeight: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    metadataWidgets() {
      return this.childItem.widgets?.reduce((metadataWidgets, widget) => {
        if (widget.type) {
          // eslint-disable-next-line no-param-reassign
          metadataWidgets[widget.type] = widget;
        }
        return metadataWidgets;
      }, {});
    },
    showCustomStatus() {
      return this.glFeatures.workItemStatusFeatureFlag && this.customStatus;
    },
    customStatus() {
      return this.metadataWidgets[WIDGET_TYPE_STATUS]?.status;
    },
    name() {
      return this.customStatus?.name;
    },
    color() {
      return this.customStatus?.color;
    },
    iconName() {
      return this.customStatus?.iconName;
    },
  },
};
</script>

<template>
  <work-item-link-child-contents
    :child-item="childItem"
    :can-update="canUpdate"
    :show-labels="showLabels"
    :work-item-full-path="workItemFullPath"
    :show-weight="showWeight"
    @click="$emit('click', $event)"
    @removeChild="$emit('removeChild', childItem)"
  >
    <template #child-contents>
      <work-item-status-badge
        v-if="showCustomStatus"
        :name="name"
        :icon-name="iconName"
        :color="color"
      />
    </template>
  </work-item-link-child-contents>
</template>
