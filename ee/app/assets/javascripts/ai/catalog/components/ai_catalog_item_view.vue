<script>
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import AiCatalogItemMetadata from './ai_catalog_item_metadata.vue';
import AiCatalogAgentDetails from './ai_catalog_agent_details.vue';
import AiCatalogFlowDetails from './ai_catalog_flow_details.vue';

const DETAILS_COMPONENT_MAP = {
  [AI_CATALOG_TYPE_AGENT]: AiCatalogAgentDetails,
  [AI_CATALOG_TYPE_FLOW]: AiCatalogFlowDetails,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: AiCatalogFlowDetails,
};

export default {
  name: 'AiCatalogItemView',
  components: {
    AiCatalogItemMetadata,
    AiCatalogAgentDetails,
    AiCatalogFlowDetails,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    detailsComponent() {
      return DETAILS_COMPONENT_MAP[this.item.itemType];
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5 @md:gl-flex-row">
    <component :is="detailsComponent" :item="item" class="gl-grow" />
    <ai-catalog-item-metadata :item="item" class="gl-shrink-0" />
  </div>
</template>
