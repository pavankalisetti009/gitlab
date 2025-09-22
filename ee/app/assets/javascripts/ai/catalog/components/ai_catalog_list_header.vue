<script>
import { GlExperimentBadge } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogNavTabs from './ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogListHeader',
  components: {
    GlExperimentBadge,
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div class="gl-flex">
          <span>{{ s__('AICatalog|AI Catalog') }}</span>
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </div>
      </template>
    </page-heading>
    <div class="gl-border-b gl-flex">
      <ai-catalog-nav-tabs />
      <ai-catalog-nav-actions />
    </div>
  </div>
</template>
