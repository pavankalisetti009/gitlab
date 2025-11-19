<script>
import { GlBadge, GlIcon, GlLink } from '@gitlab/ui';
import { __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import { FLOW_TRIGGERS_EDIT_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    GlBadge,
    GlIcon,
    GlLink,
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
    flowTrigger() {
      return this.item.configurationForProject?.flowTrigger;
    },
  },
  methods: {
    triggerName(eventType) {
      return FLOW_TRIGGER_TYPES.find((type) => type.valueInt === eventType)?.text || __('Unknown');
    },
    triggerEditPath(triggerId) {
      return {
        name: FLOW_TRIGGERS_EDIT_ROUTE,
        params: { id: getIdFromGraphQLId(triggerId) },
      };
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
        <ai-catalog-item-field v-if="projectName" :title="s__('AICatalog|Source project')">
          <gl-link :href="item.project.webUrl">{{ projectName }}</gl-link>
        </ai-catalog-item-field>
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')">
        <ai-catalog-item-field v-if="flowTrigger" :title="s__('DuoAgentsPlatform|Triggers')">
          <div class="gl-mt-3 gl-flex gl-justify-between">
            <div class="gl-flex gl-flex-wrap gl-gap-2">
              <gl-badge
                v-for="eventType in flowTrigger.eventTypes"
                :key="eventType"
                variant="neutral"
              >
                {{ triggerName(eventType) }}
              </gl-badge>
            </div>
            <gl-link
              v-if="flowTrigger.id"
              :to="triggerEditPath(flowTrigger.id)"
              class="gl-whitespace-nowrap"
            >
              <gl-icon name="pencil" /> {{ __('Edit') }}
            </gl-link>
          </div>
        </ai-catalog-item-field>
        <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
          <form-flow-definition :value="definition" read-only class="gl-mt-3" />
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>
