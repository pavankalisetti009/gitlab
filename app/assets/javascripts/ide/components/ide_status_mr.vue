<script>
import { GlIcon, GlLink } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
    GlLink,
  },
  props: {
    text: {
      type: String,
      required: true,
    },
    url: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="d-flex-center js-ide-status-mr gl-flex-nowrap text-nowrap">
    <gl-icon name="merge-request" />
    <span class="gl-hidden sm:gl-block ml-1">{{ s__('WebIDE|Merge request') }}</span>
    <gl-link class="ml-1" :href="url">{{ text }}</gl-link>
  </div>
</template>
