<script>
import { GlButton, GlDrawer, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_FLOW } from '../constants';
import AiCatalogAgentDetails from './ai_catalog_agent_details.vue';
import AiCatalogFlowDetails from './ai_catalog_flow_details.vue';

const DETAILS_COMPONENT_MAP = {
  [AI_CATALOG_TYPE_AGENT]: AiCatalogAgentDetails,
  [AI_CATALOG_TYPE_FLOW]: AiCatalogFlowDetails,
};

export default {
  name: 'AiCatalogItemDrawer',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlLoadingIcon,
    GlButton,
    GlDrawer,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
    isItemDetailsLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    activeItem: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    editRoute: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    canAdmin() {
      return Boolean(this.activeItem?.userPermissions?.adminAiCatalogItem);
    },
    getDrawerHeight() {
      return `calc(${getContentWrapperHeight()} + var(--top-bar-height))`;
    },
    activeItemId() {
      return this.activeItem ? getIdFromGraphQLId(this.activeItem.id) : '';
    },
    detailsComponent() {
      return DETAILS_COMPONENT_MAP[this.activeItem.itemType];
    },
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <gl-drawer
    :open="isOpen"
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="getDrawerHeight"
    header-sticky
    class="gl-w-full gl-leading-reset lg:gl-w-[480px] xl:gl-w-[768px] min-[1440px]:gl-w-[912px]"
    @close="$emit('close')"
  >
    <template #title>
      <div class="gl-text gl-flex gl-w-full gl-items-center gl-gap-x-4 xl:gl-px-4">
        <h2 class="gl-m-0">
          {{ activeItem.name }}
        </h2>
        <gl-button
          v-if="canAdmin"
          v-gl-tooltip
          :to="{ name: editRoute, params: { id: activeItemId } }"
          :title="s__('AICatalog|Edit')"
          category="tertiary"
          icon="pencil"
          size="small"
          :aria-label="s__('AICatalog|Edit')"
        />
      </div>
    </template>
    <template #default>
      <div class="xl:!gl-px-6" data-testid="ai-catalog-item-drawer-content">
        <dl>
          <dt>{{ s__('AICatalog|Description') }}</dt>
          <dd>{{ activeItem.description }}</dd>
          <gl-loading-icon v-if="isItemDetailsLoading" size="lg" class="gl-my-5" />
          <component :is="detailsComponent" :item="activeItem" />
        </dl>
      </div>
    </template>
  </gl-drawer>
</template>
