<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <gl-icon
    v-gl-tooltip.hover="title"
    name="information-o"
    class="gl-ml-2 gl-align-text-bottom gl-text-gray-400"
  />
</template>
