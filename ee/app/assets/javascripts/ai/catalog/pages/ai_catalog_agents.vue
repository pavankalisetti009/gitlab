<script>
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from '../components/ai_catalog_list_wrapper.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
} from '../constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    AiCatalogListHeader,
    AiCatalogListWrapper,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  data() {
    return {
      aiCatalogAgents: [],
      pageInfo: {},
      searchTerm: this.$route.query.search || '',
    };
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
      variables() {
        return {
          itemTypes: this.itemTypes,
          before: null,
          after: null,
          first: PAGE_SIZE,
          last: null,
          search: this.searchTerm,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.aiCatalogItems?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.aiCatalogItems?.pageInfo || {};
      },
    },
  },
  computed: {
    itemTypes() {
      const types = [AI_CATALOG_TYPE_AGENT];

      if (this.glFeatures.aiCatalogThirdPartyFlows) {
        types.push(AI_CATALOG_TYPE_THIRD_PARTY_FLOW);
      }
      return types;
    },
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    itemTypeConfig() {
      return {
        showRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
      };
    },
  },
  watch: {
    '$route.query.search': {
      handler(newSearch) {
        this.searchTerm = newSearch || '';
      },
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  methods: {
    handleNextPage() {
      this.$apollo.queries.aiCatalogAgents.refetch({
        ...this.$apollo.queries.aiCatalogAgents.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.aiCatalogAgents.refetch({
        ...this.$apollo.queries.aiCatalogAgents.variables,
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      });
    },
    handleSearch(filters) {
      [this.searchTerm] = filters;
      this.$router.replace({
        query: { ...this.$route.query, search: this.searchTerm || undefined },
      });
    },
    handleClearSearch() {
      this.searchTerm = '';
      const { search, ...rest } = this.$route.query;
      this.$router.replace({ query: rest });
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header />

    <ai-catalog-list-wrapper
      :is-loading="isLoading"
      :items="aiCatalogAgents"
      :item-type-config="itemTypeConfig"
      :page-info="pageInfo"
      :search-term="searchTerm"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
      @search="handleSearch"
      @clear-search="handleClearSearch"
    />
  </div>
</template>
