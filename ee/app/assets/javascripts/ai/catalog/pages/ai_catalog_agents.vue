<script>
import { isEmpty } from 'lodash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getParameterByName, updateHistory, removeParams } from '~/lib/utils/url_utility';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
      update: (data) => data.aiCatalogItems.nodes,
      result() {
        this.checkDrawerParams();
      },
    },
  },
  data() {
    return {
      aiCatalogAgents: [],
      activeItem: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    isItemSelected() {
      return !isEmpty(this.activeItem);
    },
  },
  created() {
    this.checkDrawerParams();
    window.addEventListener('popstate', this.checkDrawerParams);
  },
  beforeDestroy() {
    window.removeEventListener('popstate', this.checkDrawerParams);
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    closeDrawer() {
      this.activeItem = null;
      updateHistory({
        url: removeParams([AI_CATALOG_SHOW_QUERY_PARAM]),
      });
    },
    selectItem(item) {
      this.activeItem = item;
    },
    checkDrawerParams() {
      const urlItemId = getParameterByName(AI_CATALOG_SHOW_QUERY_PARAM);
      if (urlItemId) {
        this.activeItem =
          this.aiCatalogAgents.find((item) => this.formatId(item.id).toString() === urlItemId) ||
          null;
      } else {
        this.activeItem = null;
      }
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-list :is-loading="isLoading" :items="aiCatalogAgents" @select-item="selectItem" />
    <ai-catalog-item-drawer
      :is-open="isItemSelected"
      :active-item="activeItem"
      @close="closeDrawer"
    />
  </div>
</template>
