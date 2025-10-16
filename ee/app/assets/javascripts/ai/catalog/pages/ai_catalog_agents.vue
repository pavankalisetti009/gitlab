<script>
import { GlFilteredSearch } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemConsumerModal from '../components/ai_catalog_item_consumer_modal.vue';
import {
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
} from '../router/constants';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
} from '../constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    AiCatalogListHeader,
    AiCatalogList,
    AiCatalogItemConsumerModal,
    ErrorsAlert,
    GlFilteredSearch,
  },
  mixins: [InternalEvents.mixin()],
  data() {
    return {
      aiCatalogAgents: [],
      aiCatalogAgentToBeAdded: null,
      errors: [],
      pageInfo: {},
      searchTerm: '',
    };
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
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    itemTypeConfig() {
      return {
        actionItems: (item) => {
          if (!isLoggedIn()) {
            return [];
          }

          const id = getIdFromGraphQLId(item.id);

          const items = [
            {
              text: s__('AICatalog|Enable in project'),
              action: () => this.setAiCatalogAgentToBeAdded(item),
              icon: 'plus',
            },
            {
              text: s__('AICatalog|Duplicate'),
              to: {
                name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
                params: { id },
              },
              icon: 'duplicate',
            },
          ];

          if (!item.userPermissions?.adminAiCatalogItem) {
            return items;
          }

          const adminItems = [
            {
              text: s__('AICatalog|Edit'),
              to: {
                name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                params: { id },
              },
              icon: 'pencil',
            },
          ];

          return [...items, ...adminItems];
        },
        deleteActionItem: {
          showActionItem: (item) => item.userPermissions?.adminAiCatalogItem || false,
        },
        showRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
      };
    },
    filteredSearchValue() {
      return [
        {
          type: FILTERED_SEARCH_TERM,
          value: { data: this.searchTerm },
        },
      ];
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  methods: {
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

        this.$toast.show(s__('AICatalog|Agent deleted.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    setAiCatalogAgentToBeAdded(agent) {
      this.aiCatalogAgentToBeAdded = agent;
    },
    async addAgentToTarget(target) {
      const agent = this.aiCatalogAgentToBeAdded;

      const input = {
        itemId: agent.id,
        target,
      };

      this.setAiCatalogAgentToBeAdded(null);

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
              sprintf(s__('AICatalog|Could not enable agent: %{agentName}'), {
                agentName: agent.name,
              }),
              ...errors,
            ];
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Agent enabled in %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          sprintf(
            s__(
              'AICatalog|Could not enable agent in the project. Check that the project meets the %{link_start}prerequisites%{link_end} and try again.',
            ),
            {
              link_start: `<a href="${helpPagePath('user/duo_agent_platform/ai_catalog', {
                anchor: 'view-the-ai-catalog',
              })}" target="_blank">`,
              link_end: '</a>',
            },
            false,
          ),
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
    },
    handleClearSearch() {
      this.searchTerm = '';
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header />
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />

    <div class="gl-border-b gl-bg-subtle gl-p-5">
      <gl-filtered-search
        :value="filteredSearchValue"
        @submit="handleSearch"
        @clear="handleClearSearch"
      />
    </div>

    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogAgents"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Delete agent')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete agent %{name}?')"
      :delete-fn="deleteAgent"
      :page-info="pageInfo"
      :search="searchTerm"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
    <ai-catalog-item-consumer-modal
      v-if="aiCatalogAgentToBeAdded"
      :item="aiCatalogAgentToBeAdded"
      open
      @submit="addAgentToTarget"
      @hide="setAiCatalogAgentToBeAdded(null)"
    />
  </div>
</template>
