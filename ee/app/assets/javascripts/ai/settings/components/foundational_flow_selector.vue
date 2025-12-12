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
    isFlowSelected(reference) {
      return this.value.includes(reference);
    },
    toggleFlow(reference, checked) {
      const newSelection = checked
        ? [...this.value, reference]
        : this.value.filter((ref) => ref !== reference);

      this.$emit('input', newSelection);
    },
  },
};
</script>

<template>
  <div class="gl-ml-6 gl-mt-3">
    <gl-form-checkbox
      v-for="flow in availableFoundationalFlows"
      :key="flow.reference"
      :checked="isFlowSelected(flow.reference)"
      :disabled="disabled"
      data-testid="foundational-flow-checkbox"
      @input="toggleFlow(flow.reference, $event)"
    >
      <div>
        {{ flow.name }}
        <div class="gl-text-sm gl-text-secondary">{{ flow.description }}</div>
      </div>
    </gl-form-checkbox>
  </div>
</template>
