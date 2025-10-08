<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import FormFlowConfiguration from './form_flow_configuration.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    AiCatalogItemField,
    FormFlowConfiguration,
    FormSection,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    definition() {
      return this.item.latestVersion?.definition;
    },
    steps() {
      return (
        this.item.latestVersion?.steps?.nodes?.map(({ agent }) => ({
          agent: { name: agent.name, id: getIdFromGraphQLId(agent.id) },
        })) || []
      );
    },
  },
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">
      {{ s__('AICatalog|Flow configuration') }}
    </h3>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Basic information')">
        <ai-catalog-item-field :title="s__('AICatalog|Display name')" :value="item.name" />
        <ai-catalog-item-field :title="s__('AICatalog|Description')" :value="item.description" />
      </form-section>
      <form-section :title="s__('AICatalog|Access rights')">
        <ai-catalog-item-field
          v-if="projectName"
          :title="s__('AICatalog|Source project')"
          :value="projectName"
        />
      </form-section>
      <form-section v-if="definition" :title="s__('AICatalog|Configuration')">
        <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
          <form-flow-configuration :value="definition" read-only />
        </ai-catalog-item-field>
      </form-section>
      <form-section v-else :title="s__('AICatalog|Steps')">
        <ai-catalog-item-field :title="s__('AICatalog|Steps')">
          <div v-for="(step, index) in steps" :key="index">
            {{ step.agent.name }} ({{ step.agent.id }})
          </div>
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>
