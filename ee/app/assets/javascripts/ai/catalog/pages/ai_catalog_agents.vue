<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import setItemToDuplicateMutation from '../graphql/mutations/set_item_to_duplicate.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import AiCatalogItemConsumerModal from '../components/ai_catalog_item_consumer_modal.vue';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from '../router/constants';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_AGENT,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  TRACK_EVENT_TYPE_AGENT,
} from '../constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    AiCatalogListHeader,
    AiCatalogList,
    AiCatalogItemDrawer,
    AiCatalogItemConsumerModal,
    ErrorsAlert,
  },
  mixins: [InternalEvents.mixin()],
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
          return;
        }

        this.trackViewEvent();
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
      aiCatalogAgentToBeAdded: null,
      errors: [],
      pageInfo: {},
      hasTrackedPageView: false,
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
            text: s__('AICatalog|Add to project'),
            action: () => this.handleAiCatalogAgentToBeAdded(item),
            icon: 'plus',
          },
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
  watch: {
    hasQueryParam: {
      handler: 'trackViewIndexEvent',
      immediate: true,
    },
  },
  methods: {
    trackViewIndexEvent() {
      if (this.hasTrackedPageView || this.hasQueryParam) return;

      this.hasTrackedPageView = true;
      this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX, {
        label: TRACK_EVENT_TYPE_AGENT,
      });
    },
    trackViewEvent() {
      this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
        label: TRACK_EVENT_TYPE_AGENT,
      });
    },
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
    handleAiCatalogAgentToBeAdded({ id }) {
      const agent = this.aiCatalogAgents?.find((item) => item.id === id);
      if (typeof agent === 'undefined') {
        Sentry.captureException(
          new Error('aiCatalogAgents: Reached invalid state in Add to target action.', {
            // eslint-disable-next-line @gitlab/require-i18n-strings
            cause: `Couldn't find ${id}.`,
          }),
        );
        this.errors = [s__('AICatalog|Failed to add agent to target. Agent not found.')];
        return;
      }
      this.aiCatalogAgentToBeAdded = agent;
    },
    resetAiCatalogAgentToBeAdded() {
      this.aiCatalogAgentToBeAdded = null;
    },
    async addAgentToTarget(target) {
      const agent = this.aiCatalogAgentToBeAdded;

      const input = {
        itemId: agent.id,
        target,
      };

      this.resetAiCatalogAgentToBeAdded();

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
              sprintf(s__('AICatalog|Agent could not be added: %{agentName}'), {
                agentName: agent.name,
              }),
              ...errors,
            ];
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(
            sprintf(s__('AICatalog|Agent added successfully to %{name}.'), { name }),
          );
        }
      } catch (error) {
        this.errors = [
          sprintf(s__('AICatalog|The agent could not be enabled. Try again. %{error}'), { error }),
        ];
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
    <ai-catalog-item-consumer-modal
      v-if="aiCatalogAgentToBeAdded"
      :flow-name="aiCatalogAgentToBeAdded.name"
      @submit="addAgentToTarget"
      @hide="resetAiCatalogAgentToBeAdded"
    />
  </div>
</template>
