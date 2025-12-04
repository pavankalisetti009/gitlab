<script>
import { GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'FoundationalFlowSelector',
  components: {
    GlFormCheckbox,
  },
  inject: ['availableFoundationalFlows'],
  props: {
    value: {
      type: Array,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  methods: {
    isFlowSelected(catalogItemId) {
      return this.value.includes(catalogItemId);
    },
    toggleFlow(catalogItemId, checked) {
      const newSelection = checked
        ? [...this.value, catalogItemId]
        : this.value.filter((id) => id !== catalogItemId);

      this.$emit('input', newSelection);
    },
  },
};
</script>

<template>
  <div class="gl-ml-6 gl-mt-3">
    <gl-form-checkbox
      v-for="flow in availableFoundationalFlows"
      :key="flow.catalog_item_id"
      :checked="isFlowSelected(flow.catalog_item_id)"
      :disabled="disabled"
      data-testid="foundational-flow-checkbox"
      @input="toggleFlow(flow.catalog_item_id, $event)"
    >
      <div>
        {{ flow.name }}
        <div class="gl-text-sm gl-text-secondary">{{ flow.description }}</div>
      </div>
    </gl-form-checkbox>
  </div>
</template>
