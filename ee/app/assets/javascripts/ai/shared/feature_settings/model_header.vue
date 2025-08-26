<script>
import { GlIcon, GlTooltip } from '@gitlab/ui';

export default {
  name: 'ModelHeader',
  components: {
    GlIcon,
    GlTooltip,
  },

  props: {
    label: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <span>
    {{ label }}
    <span ref="tooltipIcon">
      <gl-icon variant="info" name="information-o" />
    </span>
    <gl-tooltip :target="() => $refs.tooltipIcon">
      <slot name="tooltip-text"></slot>
    </gl-tooltip>
  </span>
</template>
