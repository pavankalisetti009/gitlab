<script>
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import deleteAiCatalogFlowMutation from '../graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import AiCatalogItemConsumerModal from '../components/ai_catalog_item_consumer_modal.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM, AI_CATALOG_FLOWS_EDIT_ROUTE } from '../router/constants';
import { FLOW_VISIBILITY_LEVEL_DESCRIPTIONS, PAGE_SIZE } from '../constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogItemDrawer,
    AiCatalogList,
    AiCatalogListHeader,
    AiCatalogItemConsumerModal,
    ErrorsAlert,
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
        return !this.hasQueryParam;
      },
      variables() {
        return { id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.showQueryParam) };
      },
      update(data) {
        return data?.aiCatalogItem || null;
      },
      result({ data }) {
        if (typeof data === 'undefined') return;

        if (data.aiCatalogItem === null && this.hasQueryParam) {
          this.handleNotFound();
        }
      },
      error(error) {
        if (this.showQueryParam) {
          this.closeDrawer();
        }
        this.errors = [error.message];
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
      aiCatalogFlow: null,
      aiCatalogFlowToBeAdded: null,
      errors: [],
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
    showQueryParam() {
      return this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM];
    },
    hasQueryParam() {
      return Boolean(this.showQueryParam);
    },
    flowFromList() {
      if (!this.hasQueryParam) return null;

      return this.aiCatalogFlows.find(
        (n) => getIdFromGraphQLId(n.id).toString() === String(this.showQueryParam),
      );
    },
    isDrawerOpen() {
      if (!this.hasQueryParam) return false;

      // If we have the flow in the list, show drawer immediately
      if (this.flowFromList) return true;

      // If query is still loading, don't show drawer yet.
      // It might be that the flow does not exist,
      // or the user has no permission to view it.
      if (this.isItemDetailsLoading) return false;

      return Boolean(this.aiCatalogFlow);
    },
    activeFlow() {
      // Prefer the fully loaded flow from the query
      if (this.aiCatalogFlow) return this.aiCatalogFlow;

      // Fall back to flow from list if available
      if (this.flowFromList) return this.flowFromList;

      // Return minimal object with IID for loading state
      return this.hasQueryParam ? { iid: this.showQueryParam } : null;
    },
    itemTypeConfig() {
      return {
        actionItems: (itemId) => [
          {
            text: s__('AICatalog|Add to project'),
            action: () => this.handleAiCatalogFlowToBeAdded(itemId),
            icon: 'plus',
          },
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

  methods: {
    handleAiCatalogFlowToBeAdded(itemId) {
      const convertedId = convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, itemId);
      const flow = this.aiCatalogFlows?.find((item) => item.id === convertedId);
      if (typeof flow === 'undefined') {
        Sentry.captureException(
          new Error('AiCatalogFlows: Reached invalid state in Add to target action.', {
            // eslint-disable-next-line @gitlab/require-i18n-strings
            cause: `Couldn't find ${convertedId}.`,
          }),
        );
        this.errors = [s__('AICatalog|Failed to add flow to target. Flow not found.')];
        return;
      }
      this.aiCatalogFlowToBeAdded = flow;
    },
    resetAiCatalogFlowToBeAdded() {
      this.aiCatalogFlowToBeAdded = null;
    },
    closeDrawer() {
      const { show, ...otherQuery } = this.$route.query;

      this.$router.push({
        path: this.$route.path,
        query: otherQuery,
      });
    },
    handleNotFound() {
      this.errors = [s__('AICatalog|Flow not found.')];
      this.closeDrawer();
    },
    async deleteFlow(item) {
      const { id } = item;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogFlowMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogFlowsQuery],
        });

        if (!data.aiCatalogFlowDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to delete flow. %{error}'), {
              error: data.aiCatalogFlowDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Flow deleted successfully.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete flow. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    async addFlowToTarget(target) {
      const flow = this.aiCatalogFlowToBeAdded;

      const input = {
        itemId: flow.id,
        target,
      };

      this.resetAiCatalogFlowToBeAdded();

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogItemConsumer,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            // TODO: Once we have a project selector, we could add the project name in this message.
            this.errors = [
              sprintf(s__('AICatalog|Flow could not be added: %{flowName}'), {
                flowName: flow.name,
              }),
              ...errors,
            ];
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Flow added successfully to %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          sprintf(s__('AICatalog|The flow could not be enabled. Try again. %{error}'), { error }),
        ];
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
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
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
      :is-open="isDrawerOpen"
      :is-item-details-loading="isItemDetailsLoading"
      :active-item="activeFlow"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
    <ai-catalog-item-consumer-modal
      v-if="aiCatalogFlowToBeAdded"
      :flow-name="aiCatalogFlowToBeAdded.name"
      @submit="addFlowToTarget"
      @hide="resetAiCatalogFlowToBeAdded"
    />
  </div>
</template>
