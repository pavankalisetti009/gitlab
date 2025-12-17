<script>
import { GlAvatarLabeled, GlAvatarLink, GlLink } from '@gitlab/ui';
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS } from '../constants';
import { getByVersionKey } from '../utils';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import TriggerField from './trigger_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogFlowDetails',
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlLink,
    AiCatalogItemField,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
    FormSection,
    TriggerField,
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
    hasProjectConfiguration() {
      return Boolean(this.item.configurationForProject);
    },
    definition() {
      return getByVersionKey(this.item, this.versionKey).definition;
    },
    serviceAccount() {
      return this.item.configurationForGroup?.serviceAccount;
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
        <ai-catalog-item-field v-if="projectName" :title="s__('AICatalog|Managed by')">
          <gl-link :href="item.project.webUrl">{{ projectName }}</gl-link>
        </ai-catalog-item-field>
        <ai-catalog-item-visibility-field
          :public="item.public"
          :description-texts="$options.FLOW_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')">
        <ai-catalog-item-field v-if="serviceAccount" :title="s__('AICatalog|Service account')">
          <gl-avatar-link
            :href="serviceAccount.webPath"
            :title="serviceAccount.name"
            class="gl-mt-3"
          >
            <gl-avatar-labeled
              :size="32"
              :src="serviceAccount.avatarUrl"
              :label="serviceAccount.name"
              :sub-label="`@${serviceAccount.username}`"
            />
          </gl-avatar-link>
        </ai-catalog-item-field>
        <trigger-field v-if="hasProjectConfiguration" :item="item" />
        <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
          <form-flow-definition :value="definition" read-only class="gl-mt-3" />
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>
