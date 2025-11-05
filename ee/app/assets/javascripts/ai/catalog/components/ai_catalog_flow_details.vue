<script>
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    AiCatalogItemField,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
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
  },
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
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
      <form-section :title="s__('AICatalog|Visibility & access')">
        <ai-catalog-item-visibility-field
          :public="item.public"
          :description-texts="$options.FLOW_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
        <ai-catalog-item-field
          v-if="projectName"
          :title="s__('AICatalog|Source project')"
          :value="projectName"
        />
      </form-section>
      <form-section v-if="definition" :title="s__('AICatalog|Configuration')">
        <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
          <form-flow-definition :value="definition" read-only class="gl-mt-3" />
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>
