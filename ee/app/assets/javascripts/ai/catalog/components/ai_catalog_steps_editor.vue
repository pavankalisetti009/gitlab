<script>
import { GlButton } from '@gitlab/ui';
import AiCatalogNodeField from './ai_catalog_node_field.vue';

export default {
  components: {
    AiCatalogNodeField,
    GlButton,
  },
  props: {
    steps: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    formattedSteps() {
      return this.steps.map((agent) => ({
        value: agent.id,
        text: agent.name,
      }));
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-node-field
      v-for="(step, index) in formattedSteps"
      :key="index"
      :selected="step"
      class="gl-mb-3"
      aria-labelledby="flow-edit-steps"
      @primary="$emit('openAgentPanel', index)"
    />
    <gl-button icon="plus" @click="$emit('openAgentPanel', steps.length)">
      {{ s__('AICatalog|Flow node') }}
    </gl-button>
  </div>
</template>
