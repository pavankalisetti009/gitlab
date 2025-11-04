<script>
import { GlLink, GlButton } from '@gitlab/ui';
import GeoListItemStatus from './geo_list_item_status.vue';
import GeoListItemTimeAgo from './geo_list_item_time_ago.vue';
import GeoListItemErrors from './geo_list_item_errors.vue';

export default {
  components: {
    GlLink,
    GeoListItemTimeAgo,
    GeoListItemStatus,
    GeoListItemErrors,
    GlButton,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    detailsPath: {
      type: String,
      required: false,
      default: '',
    },
    statusArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    timeAgoArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    actionsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    errorsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <div class="gl-border-b gl-p-5">
    <div class="gl-flex gl-items-center gl-pb-3">
      <div>
        <gl-link v-if="detailsPath" :href="detailsPath">{{ name }}</gl-link>
        <span v-else data-testid="non-link-name">{{ name }}</span>

        <div class="gl-flex gl-flex-wrap gl-items-center">
          <span
            v-if="$scopedSlots['extra-details']"
            class="gl-px-1 gl-text-sm gl-text-subtle"
            data-testid="extra-details"
          >
            <slot name="extra-details"></slot>
            <span class="gl-ml-1">·</span>
          </span>

          <geo-list-item-time-ago
            v-for="(timeAgo, index) in timeAgoArray"
            :key="index"
            :label="timeAgo.label"
            :date-string="timeAgo.dateString"
            :default-text="timeAgo.defaultText"
            :show-divider="index < timeAgoArray.length - 1"
          />
        </div>
      </div>

      <div class="gl-ml-auto gl-self-start">
        <gl-button
          v-for="action in actionsArray"
          :key="action.id"
          :data-testid="action.id"
          :icon="action.icon"
          :loading="action.loading"
          size="small"
          class="gl-ml-3"
          @click="$emit('actionClicked', action)"
        >
          {{ action.text }}
        </gl-button>
      </div>
    </div>
    <geo-list-item-status :status-array="statusArray" />
    <geo-list-item-errors v-if="errorsArray.length" :errors-array="errorsArray" class="gl-pl-2" />
  </div>
</template>
