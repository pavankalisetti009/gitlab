<script>
import { GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TRACK_EVENT_TYPE_FLOW, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import { AI_CATALOG_FLOWS_EDIT_ROUTE } from '../router/constants';
import AiCatalogFlowDetails from '../components/ai_catalog_flow_details.vue';

export default {
  name: 'AiCatalogFlowsShow',
  components: {
    GlButton,
    PageHeading,
    AiCatalogFlowDetails,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    aiCatalogFlow: {
      type: Object,
      required: true,
    },
  },
  computed: {
    flowName() {
      return this.aiCatalogFlow.name;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  editRoute: AI_CATALOG_FLOWS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <page-heading :heading="flowName">
      <template #description>
        {{ aiCatalogFlow.description }}
      </template>
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
    <ai-catalog-flow-details :item="aiCatalogFlow" />
  </div>
</template>
