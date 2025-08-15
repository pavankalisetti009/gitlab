<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogNavTabs from './ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogListHeader',
  components: {
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|AI Catalog')" />
    <div class="gl-border-b gl-flex">
      <ai-catalog-nav-tabs />
      <ai-catalog-nav-actions />
    </div>
  </div>
</template>
