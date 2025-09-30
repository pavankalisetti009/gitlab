<script>
export default {
  props: {
    title: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div>
    <dt class="gl-text-subtle">{{ title }}</dt>
    <dd class="gl-mb-0">
      <template v-if="$scopedSlots.default">
        <slot></slot>
      </template>
      <template v-else-if="value">
        {{ value }}
      </template>
    </dd>
  </div>
</template>
