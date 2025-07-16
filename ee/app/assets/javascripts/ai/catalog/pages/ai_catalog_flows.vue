<script>
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogList,
  },
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      update: (data) => data.aiCatalogItems.nodes,
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
    },
  },
};
</script>

<template>
  <ai-catalog-list :is-loading="isLoading" :items="aiCatalogFlows" />
</template>
