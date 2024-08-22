<script>
export default {
  props: {
    label: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <h5 class="gl-mt-6 gl-text-primary" data-testid="label">{{ label }}</h5>
    <p class="gl-text-primary" data-testid="content"><slot></slot></p>
  </div>
</template>
