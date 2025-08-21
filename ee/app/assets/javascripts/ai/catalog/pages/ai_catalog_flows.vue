<script>
import { GlAlert } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS, PAGE_SIZE } from 'ee/ai/catalog/constants';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import deleteAiCatalogFlowMutation from '../graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM, AI_CATALOG_FLOWS_EDIT_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    GlAlert,
    AiCatalogListHeader,
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      variables() {
        return {
          before: null,
          after: null,
          first: PAGE_SIZE,
          last: null,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogItems.nodes,
      result({ data }) {
        this.pageInfo = data.aiCatalogItems.pageInfo;
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
        this.errorMessage = error.message;
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
      aiCatalogFlow: {},
      errorMessage: null,
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
    },
    isItemDetailsLoading() {
      return this.$apollo.queries.aiCatalogFlow.loading;
    },
    isItemSelected() {
      return Boolean(this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM]);
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
    activeFlow() {
      if (!this.isItemDetailsLoading) return this.aiCatalogFlow;

      // Returns the fully-loaded flow if available from aiCatalogFlows
      const iid = this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM];
      if (!iid) return {};

      const fromList = this.aiCatalogFlows.find(
        (n) => this.formatId(n.id).toString() === String(iid),
      );
      return fromList || { iid };
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
    async deleteFlow(id) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogFlowMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogFlowsQuery],
        });

        if (!data.aiCatalogFlowDelete.success) {
          this.errorMessage = sprintf(s__('AICatalog|Failed to delete flow. %{error}'), {
            error: data.aiCatalogFlowDelete.errors?.[0],
          });
          return;
        }

        this.$toast.show(s__('AICatalog|Flow deleted successfully.'));
      } catch (error) {
        this.errorMessage = sprintf(s__('AICatalog|Failed to delete flow. %{error}'), { error });
        Sentry.captureException(error);
      }
    },
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
  },
  editRoute: AI_CATALOG_FLOWS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <ai-catalog-list-header />
    <gl-alert
      v-if="errorMessage"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      @dismiss="errorMessage = null"
      >{{ errorMessage }}
    </gl-alert>
    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogFlows"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Delete flow')"
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
