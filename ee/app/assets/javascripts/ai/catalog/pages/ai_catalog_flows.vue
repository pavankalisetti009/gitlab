<script>
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { InternalEvents } from '~/tracking';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from '../components/ai_catalog_list_wrapper.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import {
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_FLOW,
} from '../constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogListWrapper,
    AiCatalogListHeader,
  },
  mixins: [InternalEvents.mixin()],
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      variables() {
        return {
          before: null,
          after: null,
          first: PAGE_SIZE,
          last: null,
          search: this.searchTerm,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogItems.nodes,
      result({ data }) {
        this.pageInfo = data.aiCatalogItems.pageInfo;
      },
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
      pageInfo: {},
      searchTerm: '',
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
    },
    itemTypeConfig() {
      return {
        showRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
      };
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX, {
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  methods: {
    handleNextPage() {
      this.$apollo.queries.aiCatalogFlows.refetch({
        ...this.$apollo.queries.aiCatalogFlows.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.aiCatalogFlows.refetch({
        ...this.$apollo.queries.aiCatalogFlows.variables,
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      });
    },
    handleSearch(filters) {
      [this.searchTerm] = filters;
    },
    handleClearSearch() {
      this.searchTerm = '';
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header :is-beta="true" />

    <ai-catalog-list-wrapper
      :is-loading="isLoading"
      :items="aiCatalogFlows"
      :item-type-config="itemTypeConfig"
      :page-info="pageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
      @search="handleSearch"
      @clear-search="handleClearSearch"
    />
  </div>
</template>
