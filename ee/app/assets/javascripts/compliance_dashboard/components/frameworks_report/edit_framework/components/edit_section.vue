<script>
import { GlButton, GlCollapse } from '@gitlab/ui';

export default {
  components: {
    GlButton,
    GlCollapse,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    expandable: {
      type: Boolean,
      required: false,
      default: false,
    },
    initiallyExpanded: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data(props) {
    return {
      isExpanded: props.initiallyExpanded,
    };
  },

  computed: {
    isCurrentlyExpanded() {
      return !this.expandable || this.isExpanded;
    },
  },

  methods: {
    toggleExpand() {
      this.isExpanded = !this.isExpanded;
    },
  },
};
</script>
<template>
  <div>
    <div
      class="gl-my-4 gl-flex gl-items-center gl-bg-gray-10 gl-p-4"
      :class="{
        'gl-cursor-pointer': expandable,
      }"
      @click="toggleExpand"
    >
      <div class="gl-grow">
        <div class="gl-text-size-h2 gl-font-bold">
          {{ title }}
        </div>
        <span>{{ description }}</span>
      </div>
      <gl-button v-if="expandable" @click.stop="toggleExpand">
        {{ isExpanded ? __('Collapse') : __('Expand') }}
      </gl-button>
    </div>
    <gl-collapse :visible="isCurrentlyExpanded" class="gl-p-4">
      <slot></slot>
    </gl-collapse>
  </div>
</template>
