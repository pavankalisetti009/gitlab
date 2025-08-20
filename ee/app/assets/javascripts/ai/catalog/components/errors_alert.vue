<script>
import { GlAlert } from '@gitlab/ui';

export default {
  name: 'ErrorsAlert',
  components: {
    GlAlert,
  },
  props: {
    errorMessages: {
      type: Array,
      required: true,
    },
  },
  watch: {
    errorMessages: {
      handler(newValue) {
        if (newValue.length === 0) {
          return;
        }

        this.$nextTick(() => {
          this.$refs.alertRef?.$el?.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
          });
        });
      },
      immediate: true,
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="errorMessages.length > 0"
    ref="alertRef"
    variant="danger"
    class="gl-mb-5"
    @dismiss="$emit('dismiss')"
  >
    <span v-if="errorMessages.length === 1">
      {{ errorMessages[0] }}
    </span>
    <ul v-else class="!gl-mb-0 gl-pl-5">
      <li v-for="(errorMessage, index) in errorMessages" :key="index">
        {{ errorMessage }}
      </li>
    </ul>
  </gl-alert>
</template>
