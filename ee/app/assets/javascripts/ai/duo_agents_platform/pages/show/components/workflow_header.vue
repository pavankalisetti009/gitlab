<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  components: {
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    prompt: {
      required: true,
      type: String,
    },
  },
};
</script>
<template>
  <div>
    <div v-if="isLoading" class="gl-mt-6">
      <gl-skeleton-loader :lines="1" :width="400" />
    </div>
    <h1 v-else class="gl-truncate gl-text-size-h1">
      {{ prompt || s__('DuoAgentsPlatform|Prompt is unavailable') }}
    </h1>
  </div>
</template>
