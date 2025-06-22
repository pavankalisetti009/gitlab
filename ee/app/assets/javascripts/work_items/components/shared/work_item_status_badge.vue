<script>
import { GlIcon } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    iconName: {
      type: String,
      required: true,
    },
    color: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    colorStyle() {
      return this.color ? { color: this.color } : {};
    },
  },
};
</script>

<template>
  <div
    class="work-item-status gl-inline-flex gl-max-w-full gl-items-center gl-rounded-pill gl-bg-strong gl-py-1 gl-pl-2 gl-pr-[.375rem] gl-text-sm gl-leading-normal gl-text-strong"
    data-testid="work-item-status"
    :aria-label="name"
  >
    <gl-icon class="gl-shrink-0" :size="12" :name="iconName" :style="colorStyle" />
    <span class="gl-ml-2 gl-truncate">{{ name }}</span>
  </div>
</template>
