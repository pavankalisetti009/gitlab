<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import setItemToDuplicateMutation from '../graphql/mutations/set_item_to_duplicate.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from '../router/constants';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  AI_CATALOG_TYPE_AGENT,
} from '../constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    AiCatalogListHeader,
    AiCatalogList,
    AiCatalogItemDrawer,
    ErrorsAlert,
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
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
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
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
      aiCatalogAgents: [],
      aiCatalogAgent: null,
      errors: [],
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    isItemDetailsLoading() {
      return this.$apollo.queries.aiCatalogAgent.loading;
    },
    showQueryParam() {
      return this.$route.query[AI_CATALOG_SHOW_QUERY_PARAM];
    },
    hasQueryParam() {
      return Boolean(this.showQueryParam);
    },
    agentFromList() {
      if (!this.hasQueryParam) return null;

      return this.aiCatalogAgents.find(
        (n) => getIdFromGraphQLId(n.id).toString() === String(this.showQueryParam),
      );
    },
    isDrawerOpen() {
      if (!this.hasQueryParam) return false;

      // If we have the agent in the list, show drawer immediately
      if (this.agentFromList) return true;

      // If query is still loading, don't show drawer yet.
      // It might be that the agent does not exist,
      // or the user has no permission to view it.
      if (this.isItemDetailsLoading) return false;

      return Boolean(this.aiCatalogAgent);
    },
    activeAgent() {
      // Prefer the fully loaded agent from the query
      if (this.aiCatalogAgent) return this.aiCatalogAgent;

      // Fall back to agent from list if available
      if (this.agentFromList) return this.agentFromList;

      // Return minimal object with IID for loading state
      return this.hasQueryParam ? { iid: this.showQueryParam } : null;
    },
    itemTypeConfig() {
      return {
        actionItems: (item) => [
          {
            text: s__('AICatalog|Test run'),
            to: {
              name: AI_CATALOG_AGENTS_RUN_ROUTE,
              params: { id: getIdFromGraphQLId(item.id) },
            },
            icon: 'rocket-launch',
          },
          {
            text: s__('AICatalog|Duplicate'),
            action: () => this.handleDuplicate(item),
            icon: 'duplicate',
          },
          {
            text: s__('AICatalog|Edit'),
            to: {
              name: AI_CATALOG_AGENTS_EDIT_ROUTE,
              params: { id: getIdFromGraphQLId(item.id) },
            },
            icon: 'pencil',
          },
        ],
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
      };
    },
  },
  methods: {
    closeDrawer() {
      const { show, ...otherQuery } = this.$route.query;

      this.$router.push({
        path: this.$route.path,
        query: otherQuery,
      });
    },
    handleNotFound() {
      this.errors = [s__('AICatalog|Agent not found.')];
      this.closeDrawer();
    },
    async deleteAgent(item) {
      const { id } = item;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogAgentMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogAgentsQuery],
        });

        if (!data.aiCatalogAgentDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
              error: data.aiCatalogAgentDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Agent deleted successfully.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    handleNextPage() {
      this.$apollo.queries.aiCatalogAgents.refetch({
        ...this.$apollo.queries.aiCatalogAgents.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    async handleDuplicate(agent) {
      try {
        if (!agent) {
          throw new Error(s__('AICatalog|Agent not found.'));
        }

        const iid = getIdFromGraphQLId(agent.id);

        await this.$apollo.mutate({
          mutation: setItemToDuplicateMutation,
          variables: {
            item: {
              id: iid,
              type: AI_CATALOG_TYPE_AGENT,
              data: agent,
            },
          },
        });

        this.$router.push({
          name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
          params: { id: iid },
        });
      } catch (error) {
        this.errors = [error.message];
        Sentry.captureException(error);
      }
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
  },
  editRoute: AI_CATALOG_AGENTS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <ai-catalog-list-header />
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogAgents"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Delete agent')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete agent %{name}?')"
      :delete-fn="deleteAgent"
      :page-info="pageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
    <ai-catalog-item-drawer
      :is-open="isDrawerOpen"
      :is-item-details-loading="isItemDetailsLoading"
      :active-item="activeAgent"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
