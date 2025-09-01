<script>
import { s__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import {
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';

export default {
  name: 'AiFlows',
  components: {
    PageHeading,
    ErrorsAlert,
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  inject: ['projectId'],
  apollo: {
    aiFlows: {
      query: aiCatalogConfiguredItemsQuery,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          before: null,
          after: null,
          first: PAGE_SIZE,
          last: null,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogConfiguredItems.nodes,
      result({ data }) {
        this.pageInfo = data.aiCatalogConfiguredItems.pageInfo;
      },
    },
    aiCatalogFlow: {
      query: aiCatalogFlowQuery,
      skip() {
        return !this.isItemSelected;
      },
      variables() {
        const iid = this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM];
        return { id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, iid) };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        if (this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM]) {
          this.closeDrawer();
        }
        this.errors = [error.message];
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      aiFlows: [],
      aiCatalogFlow: {},
      errors: [],
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiFlows.loading;
    },
    isItemDetailsLoading() {
      return this.$apollo.queries.aiCatalogFlow.loading;
    },
    isItemSelected() {
      return Boolean(this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM]);
    },
    items() {
      return this.aiFlows.map((flow) => flow.item);
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
      };
    },
    activeFlow() {
      if (!this.isItemDetailsLoading) return this.aiCatalogFlow;

      // Returns the fully-loaded flow if available from aiFlows
      const iid = this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM];
      if (!iid) return {};

      const fromList = this.aiFlows.find(
        (n) => this.formatId(n.item.id).toString() === String(iid),
      );
      return fromList?.item || { iid };
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    closeDrawer() {
      const { show, ...otherQuery } = this.$route.query;

      this.$router.push({
        path: this.$route.path,
        query: otherQuery,
      });
    },
    async deleteFlow() {
      // TODO: Add delete flow function
    },
    handleNextPage() {
      this.$apollo.queries.aiFlows.refetch({
        ...this.$apollo.queries.aiFlows.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.aiFlows.refetch({
        ...this.$apollo.queries.aiFlows.variables,
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      });
    },
  },
  editRoute: AI_CATALOG_FLOWS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Flows')" />

    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <ai-catalog-list
      :is-loading="isLoading"
      :items="items"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Delete flow (Coming soon)')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
      :delete-fn="deleteFlow"
      :page-info="pageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
    <ai-catalog-item-drawer
      :is-open="isItemSelected"
      :is-item-details-loading="isItemDetailsLoading"
      :active-item="activeFlow"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
