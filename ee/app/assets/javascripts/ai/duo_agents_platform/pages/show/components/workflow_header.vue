<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    workflowDefinition: {
      required: true,
      type: String,
    },
  },
  computed: {
    pageTitle() {
      return `${this.workflowDefinition || s__('DuoAgentsPlatform|Agent Flow')} #${this.$route.params.id}`;
    },
  },
};
</script>
<template>
  <div class="gl-mt-6">
    <div v-if="isLoading">
      <gl-skeleton-loader :lines="1" :width="400" />
    </div>
    <div v-else>
      <h1 class="gl-heading-1">{{ pageTitle }}</h1>
    </div>
  </div>
</template>
