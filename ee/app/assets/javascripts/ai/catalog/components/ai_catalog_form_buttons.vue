<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'AiCatalogFormButtons',
  components: {
    GlButton,
  },
  props: {
    isDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    indexRoute: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-gap-3">
    <slot></slot>
    <gl-button
      :disabled="isDisabled"
      :to="{ name: indexRoute }"
      type="button"
      category="secondary"
      class="gl-w-full sm:gl-w-auto"
    >
      {{ __('Cancel') }}
    </gl-button>
  </div>
</template>
