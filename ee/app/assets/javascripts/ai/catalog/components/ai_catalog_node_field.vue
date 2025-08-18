<script>
import { GlButtonGroup, GlButton, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlButtonGroup,
    GlButton,
    GlIcon,
  },
  props: {
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    primaryButtonText() {
      return this.selected?.text || s__('AICatalog| Draft node');
    },
  },
};
</script>

<template>
  <gl-button-group class="gl-flex gl-w-full">
    <gl-button disabled class="!gl-flex-none">
      <slot name="button-content">
        {{ s__('AICatalog| Agent') }}
      </slot>
    </gl-button>
    <gl-button @click="$emit('primary')">
      <slot name="button-content">
        {{ primaryButtonText }}
      </slot>
    </gl-button>
    <gl-button disabled class="!gl-flex-none" :aria-label="__('Reorder')">
      <gl-icon name="grip" />
    </gl-button>
  </gl-button-group>
</template>
