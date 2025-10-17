<script>
import { AGENT_VISIBILITY_LEVEL_DESCRIPTIONS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    AiCatalogItemField,
    AiCatalogItemVisibilityField,
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
    systemPrompt() {
      return this.item.latestVersion?.systemPrompt;
    },
    tools() {
      return this.item.latestVersion?.tools?.nodes
        .map((t) => t.title)
        .sort()
        .join(', ');
    },
  },
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">
      {{ s__('AICatalog|Agent configuration') }}
    </h3>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Basic information')">
        <ai-catalog-item-field :title="s__('AICatalog|Display name')" :value="item.name" />
        <ai-catalog-item-field :title="s__('AICatalog|Description')" :value="item.description" />
      </form-section>
      <form-section :title="s__('AICatalog|Visibility & access')">
        <ai-catalog-item-visibility-field
          :public="item.public"
          :description-texts="$options.AGENT_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
        <ai-catalog-item-field
          v-if="projectName"
          :title="s__('AICatalog|Source project')"
          :value="projectName"
        />
      </form-section>
      <form-section :title="s__('AICatalog|Prompts')">
        <ai-catalog-item-field v-if="systemPrompt" :title="s__('AICatalog|System prompt')">
          <div class="gl-border gl-mb-3 gl-mt-2 gl-rounded-default gl-bg-default gl-p-3">
            <pre class="gl-m-0 gl-whitespace-pre-wrap">{{ systemPrompt }}</pre>
          </div>
        </ai-catalog-item-field>
      </form-section>
      <form-section v-if="tools" :title="s__('AICatalog|Available tools')">
        <ai-catalog-item-field :title="s__('AICatalog|Tools')" :value="tools" />
      </form-section>
    </dl>
  </div>
</template>
