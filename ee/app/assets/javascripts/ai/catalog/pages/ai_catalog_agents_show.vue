<script>
import { GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TRACK_EVENT_TYPE_AGENT, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import { AI_CATALOG_AGENTS_EDIT_ROUTE } from '../router/constants';
import AiCatalogAgentDetails from '../components/ai_catalog_agent_details.vue';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    GlButton,
    PageHeading,
    AiCatalogAgentDetails,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    aiCatalogAgent: {
      type: Object,
      required: true,
    },
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent.name;
    },
    projectName() {
      return this.aiCatalogAgent.project?.name;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  editRoute: AI_CATALOG_AGENTS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <page-heading :heading="agentName">
      <template #actions>
        <gl-button
          :to="{ name: $options.editRoute, params: { id: $route.params.id } }"
          type="button"
          category="secondary"
        >
          {{ __('Edit') }}
        </gl-button>
      </template>
    </page-heading>
    <dl>
      <template v-if="projectName">
        <dt>{{ s__('AICatalog|Project') }}</dt>
        <dd>{{ projectName }}</dd>
      </template>
      <dt>{{ s__('AICatalog|Description') }}</dt>
      <dd>{{ aiCatalogAgent.description }}</dd>
      <ai-catalog-agent-details :item="aiCatalogAgent" />
    </dl>
  </div>
</template>
