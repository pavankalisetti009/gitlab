<script>
import { GlIcon, GlLink, GlSprintf, GlToken } from '@gitlab/ui';
import { __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import {
  FLOW_TRIGGERS_NEW_ROUTE,
  FLOW_TRIGGERS_EDIT_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';

export default {
  name: 'TriggerField',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    GlToken,
    AiCatalogItemField,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    flowTrigger() {
      return this.item.configurationForProject?.flowTrigger;
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
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
  FLOW_TRIGGERS_NEW_ROUTE,
};
</script>

<template>
  <ai-catalog-item-field :title="s__('DuoAgentsPlatform|Triggers')">
    <div v-if="flowTrigger" class="gl-mt-3 gl-flex gl-justify-between">
      <div class="gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
        <gl-token v-for="eventType in flowTrigger.eventTypes" :key="eventType" view-only>
          {{ triggerName(eventType) }}
        </gl-token>
      </div>
      <gl-link
        v-if="flowTrigger.id && !item.foundational"
        :to="triggerEditPath(flowTrigger.id)"
        class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
      >
        <gl-icon name="pencil" />
        {{ __('Edit') }}
      </gl-link>
    </div>
    <div v-else class="gl-text-subtle">
      <gl-sprintf
        :message="
          s__(
            'AICatalog|No triggers configured. %{linkStart}Add a trigger%{linkEnd} to make this %{itemType} available.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :to="{ name: $options.FLOW_TRIGGERS_NEW_ROUTE }">{{ content }}</gl-link>
        </template>
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
    </div>
  </ai-catalog-item-field>
</template>
