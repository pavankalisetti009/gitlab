<script>
import { GlButton, GlIcon } from '@gitlab/ui';

export default {
  components: {
    GlButton,
    GlIcon,
  },
  props: {
    isFinished: {
      type: Boolean,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    editButtonText: {
      type: String,
      required: true,
    },
    isEditable: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['edit'],
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-justify-between" :class="isFinished ? 'gl-mb-2' : ''">
    <div class="gl-flex gl-items-center">
      <gl-icon
        v-show="isFinished"
        class="gl-mr-2 gl-text-green-500"
        :size="16"
        :aria-label="title"
        name="check-circle"
      />
      <h5 class="gl-my-0">{{ title }}</h5>
    </div>
    <div v-if="isEditable" class="gl-flex gl-flex-col gl-justify-center">
      <gl-button size="small" @click="$emit('edit')">{{ editButtonText }}</gl-button>
    </div>
  </div>
</template>
