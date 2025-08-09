<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { AGENT_VISIBILITY_LEVEL_DESCRIPTIONS, PAGE_SIZE } from 'ee/ai/catalog/constants';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from '../router/constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    GlAlert,
    AiCatalogList,
    AiCatalogItemDrawer,
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
        this.checkDrawerParams();
        this.pageInfo = data.aiCatalogItems.pageInfo;
      },
    },
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      skip() {
        return !this.isItemSelected;
      },
      variables() {
        return {
          id: this.activeItem.id,
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        this.errorMessage = error.message;
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      aiCatalogAgents: [],
      aiCatalogAgent: {},
      activeItem: null,
      errorMessage: null,
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
    isItemSelected() {
      return Boolean(this.activeItem?.id);
    },
    itemTypeConfig() {
      return {
        actionItems: (itemId) => [
          {
            text: s__('AICatalog|Test run'),
            to: {
              name: AI_CATALOG_AGENTS_RUN_ROUTE,
              params: { id: itemId },
            },
            icon: 'rocket-launch',
          },
          {
            text: s__('AICatalog|Edit'),
            to: {
              name: AI_CATALOG_AGENTS_EDIT_ROUTE,
              params: { id: itemId },
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
    activeAgent() {
      if (this.isItemDetailsLoading) {
        return this.activeItem;
      }

      return this.aiCatalogAgent;
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
    async deleteAgent(id) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogAgentMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogAgentsQuery],
        });

        if (!data.aiCatalogAgentDelete.success) {
          this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
            error: data.aiCatalogAgentDelete.errors?.[0],
          });
          return;
        }

        this.$toast.show(s__('AICatalog|Agent deleted successfully.'));
      } catch (error) {
        this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error });
        Sentry.captureException(error);
      }
    },
    checkDrawerParams() {
      const urlItemId = this.$route.query?.[AI_CATALOG_SHOW_QUERY_PARAM];
      if (urlItemId) {
        this.activeItem =
          this.aiCatalogAgents.find(
            (item) => this.formatId(item.id).toString() === urlItemId.toString(),
          ) || null;
      } else {
        this.activeItem = null;
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
    <gl-alert
      v-if="errorMessage"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      @dismiss="errorMessage = null"
      >{{ errorMessage }}
    </gl-alert>
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
      :is-open="isItemSelected"
      :is-item-details-loading="isItemDetailsLoading"
      :active-item="activeAgent"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
