<script>
export default {
  name: 'SecurityFindingsPage',
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isPipelineActive() {
      return this.mr.isPipelineActive ?? false;
    },
  },
};
</script>

<template>
  <div data-testid="security-findings-page">
    <span>{{ isPipelineActive }}</span>
  </div>
</template>
