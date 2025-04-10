<script>
import { GlBadge, GlIcon } from '@gitlab/ui';

export default {
  components: {
    GlBadge,
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
  <gl-badge variant="muted" class="!gl-items-center !gl-pl-2" :aria-label="name">
    <div class="gl-truncate">
      <gl-icon :size="12" :name="iconName" class="gl-mb-[-1px] gl-mr-1" :style="colorStyle" />
      <span>{{ name }}</span>
    </div>
  </gl-badge>
</template>
