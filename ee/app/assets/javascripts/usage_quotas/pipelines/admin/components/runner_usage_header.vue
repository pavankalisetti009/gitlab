<script>
import { GlLoadingIcon } from '@gitlab/ui';

export default {
  components: {
    GlLoadingIcon,
  },
  props: {
    monthlyUsage: {
      type: Number,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>
<template>
  <div>
    <h2 class="gl-heading-3 gl-my-3" data-testid="overview-subtitle">
      {{ __('Hosted runner usage') }}
    </h2>

    <div class="gl-pb-4">
      <span class="gl-text-subtle">{{ __('Usage this month') }}</span>
      <gl-loading-icon v-if="loading" />
      <div v-else class="gl-block" data-testid="hosted-runner-monthly-usage">
        <span class="gl-heading-3">{{ monthlyUsage }}</span>
        <span class="gl-font-bold">{{ __('minutes') }}</span>
      </div>
    </div>
  </div>
</template>
