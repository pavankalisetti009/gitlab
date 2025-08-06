<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS } from 'ee/ai/catalog/constants';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM, AI_CATALOG_FLOWS_EDIT_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogItems.nodes,
      result() {
        this.checkDrawerParams();
      },
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
      activeItem: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
    },
    itemTypeConfig() {
      return {
        actionItems: (itemId) => [
          {
            text: s__('AICatalog|Edit'),
            to: {
              name: AI_CATALOG_FLOWS_EDIT_ROUTE,
              params: { id: itemId },
            },
            icon: 'pencil',
          },
        ],
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
      };
    },
  },
  watch: {
    '$route.query.show': {
      handler() {
        this.checkDrawerParams();
      },
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    closeDrawer() {
      this.activeItem = null;
      const { show, ...otherQuery } = this.$route.query;

      this.$router.push({
        path: this.$route.path,
        query: otherQuery,
      });
    },
    checkDrawerParams() {
      const urlItemId = this.$route.query?.[AI_CATALOG_SHOW_QUERY_PARAM];
      if (urlItemId) {
        // TODO: Fetch flow details from the API: https://gitlab.com/gitlab-org/gitlab/-/issues/557201
        this.activeItem =
          this.aiCatalogFlows?.find(
            (item) => this.formatId(item.id).toString() === urlItemId.toString(),
          ) || null;
      } else {
        this.activeItem = null;
      }
    },
  },
  editRoute: AI_CATALOG_FLOWS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogFlows"
      :item-type-config="itemTypeConfig"
    />
    <ai-catalog-item-drawer
      :is-open="activeItem !== null"
      :active-item="activeItem"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
