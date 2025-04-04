<script>
import { GlAnimatedChevronLgRightDownIcon, GlCollapse } from '@gitlab/ui';

export default {
  components: {
    GlCollapse,
    GlAnimatedChevronLgRightDownIcon,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      selectedItem: null,
    };
  },
  methods: {
    toggleDetails(item) {
      this.selectedItem = this.selectedItem === item ? null : item;
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div v-for="(item, index) in items" :key="index">
      <div
        role="button"
        class="gl-flex gl-cursor-pointer gl-select-none gl-flex-row gl-items-center gl-bg-strong gl-px-5 gl-py-3"
        @click="toggleDetails(item)"
      >
        <div>
          <slot name="header" :item="item"></slot>
        </div>
        <gl-animated-chevron-lg-right-down-icon class="gl-ml-auto" :is-on="selectedItem === item" />
      </div>
      <gl-collapse :visible="selectedItem === item" class="gl-p-3">
        <slot :item="item"></slot>
      </gl-collapse>
    </div>
  </div>
</template>
