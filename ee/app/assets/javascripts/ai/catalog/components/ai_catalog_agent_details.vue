<script>
import { GlLink, GlToken, GlTruncateText } from '@gitlab/ui';
import { getByVersionKey } from '../utils';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import TriggerField from './trigger_field.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogAgentDetails',
  components: {
    AiCatalogItemField,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
    FormSection,
    GlLink,
    GlToken,
    GlTruncateText,
    TriggerField,
  },
  truncateTextToggleButtonProps: {
    class: 'gl-font-regular',
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  computed: {
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    version() {
      return getByVersionKey(this.item, this.versionKey);
    },
    toolTitles() {
      return (this.version.tools?.nodes ?? []).map((t) => t.title).sort();
    },
    systemPrompt() {
      return this.version.systemPrompt;
    },
    definition() {
      return this.version.definition;
    },
    isThirdPartyFlow() {
      return this.item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    hasProjectConfiguration() {
      return Boolean(this.item.configurationForProject);
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
        <ai-catalog-item-field v-if="projectName" :title="s__('AICatalog|Managed by')">
          <gl-link :href="item.project.webUrl">{{ projectName }}</gl-link>
        </ai-catalog-item-field>
        <ai-catalog-item-visibility-field
          :public="item.public"
          :description-texts="$options.AGENT_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')">
        <template v-if="isThirdPartyFlow">
          <ai-catalog-item-field
            :title="s__('AICatalog|Type')"
            :value="s__('AICatalog|External')"
          />
          <trigger-field v-if="hasProjectConfiguration" :item="item" />
          <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
            <form-flow-definition :value="definition" read-only class="gl-mt-3" />
          </ai-catalog-item-field>
        </template>
        <template v-else>
          <ai-catalog-item-field :title="s__('AICatalog|Type')" :value="s__('AICatalog|Custom')" />
          <ai-catalog-item-field :title="s__('AICatalog|System prompt')">
            <div class="gl-border gl-mt-3 gl-rounded-default gl-bg-default gl-p-3">
              <pre class="gl-m-0 gl-whitespace-pre-wrap"><gl-truncate-text
              :lines="20"
              :show-more-text="__('Show more')"
              :show-less-text="__('Show less')"
              :toggle-button-props="$options.truncateTextToggleButtonProps"
              class="gl-flex gl-flex-col gl-items-start gl-gap-3"
            >{{ systemPrompt }}</gl-truncate-text></pre>
            </div>
          </ai-catalog-item-field>
          <ai-catalog-item-field :title="s__('AICatalog|Tools')">
            <span v-if="toolTitles.length === 0" class="gl-text-subtle">
              {{ __('None') }}
            </span>
            <div v-else class="gl-mt-3 gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
              <gl-token v-for="tool in toolTitles" :key="tool" view-only>
                {{ tool }}
              </gl-token>
            </div>
          </ai-catalog-item-field>
        </template>
      </form-section>
    </dl>
  </div>
</template>
