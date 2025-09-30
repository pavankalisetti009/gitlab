<script>
export default {
  props: {
    title: {
      type: String,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div class="gl-border gl-flex gl-flex-col gl-gap-5 gl-rounded-base gl-bg-subtle gl-p-5">
    <h4 class="gl-my-0 gl-text-base gl-uppercase gl-text-subtle">{{ title }}</h4>
    <slot></slot>
  </div>
</template>
