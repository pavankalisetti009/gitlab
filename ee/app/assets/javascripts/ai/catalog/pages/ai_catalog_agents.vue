<script>
import { GlFilteredSearch } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemConsumerModal from '../components/ai_catalog_item_consumer_modal.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
} from '../constants';
import { prerequisitesError } from '../utils';

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
          prerequisitesError(
            s__(
              'AICatalog|Could not enable agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
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
