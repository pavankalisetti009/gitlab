<script>
import { GlButton, GlBadge } from '@gitlab/ui';

export default {
  components: {
    GlButton,
    GlBadge,
  },
  props: {
    securityAttributeCategories: {
      type: Array,
      required: true,
    },
    selectedCategory: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-mb-4 gl-flex gl-items-center gl-justify-between">
      <h4 class="gl-text-lg">{{ s__('SecurityAttributes|Categories') }}</h4>
      <gl-button
        category="primary"
        variant="confirm"
        size="small"
        @click="$emit('selectCategory', {})"
        >{{ s__('SecurityAttributes|Create category') }}</gl-button
      >
    </div>
    <div
      v-for="category in securityAttributeCategories"
      :key="category.id"
      class="gl-my-1 gl-flex gl-cursor-pointer gl-items-center gl-rounded-base gl-p-3 hover:!gl-bg-status-neutral"
      :class="{ 'gl-bg-strong': selectedCategory.id === category.id }"
      :data-testid="`attribute-category-${category.id}`"
      @click="$emit('selectCategory', category)"
    >
      <div>
        <div :class="{ 'gl-font-bold': selectedCategory.id === category.id }">
          {{ category.name }}
        </div>
        <div class="gl-h-7 gl-overflow-hidden gl-text-ellipsis gl-text-sm gl-text-subtle">
          {{ category.description }}
        </div>
      </div>
      <gl-badge>{{ category.attributeCount }}</gl-badge>
    </div>
  </div>
</template>
