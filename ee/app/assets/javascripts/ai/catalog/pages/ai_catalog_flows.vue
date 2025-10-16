<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import { isLoggedIn } from '~/lib/utils/common_utils';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { InternalEvents } from '~/tracking';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemConsumerModal from '../components/ai_catalog_item_consumer_modal.vue';
import {
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from '../router/constants';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  FLOW_TYPE_APOLLO_CONFIG,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_FLOW,
} from '../constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogList,
    AiCatalogListHeader,
    AiCatalogItemConsumerModal,
    ErrorsAlert,
    GlFilteredSearch,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      variables() {
        return {
          ...this.itemTypes,
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
      aiCatalogFlowToBeAdded: null,
      errors: [],
      pageInfo: {},
      searchTerm: '',
    };
  },
  computed: {
    isFlowsAvailable() {
      return this.glFeatures.aiCatalogFlows;
    },
    isThirdPartyFlowsAvailable() {
      return this.glFeatures.aiCatalogThirdPartyFlows;
    },
    itemTypes() {
      if (this.isThirdPartyFlowsAvailable && this.isFlowsAvailable) {
        return { itemTypes: [AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW] };
      }
      if (this.isThirdPartyFlowsAvailable) {
        return { itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW };
      }
      return { itemType: AI_CATALOG_TYPE_FLOW };
    },
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
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
              action: () => this.setAiCatalogFlowToBeAdded(item),
              icon: 'plus',
            },
            {
              text: s__('AICatalog|Duplicate'),
              to: {
                name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
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
                name: AI_CATALOG_FLOWS_EDIT_ROUTE,
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
        showRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
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
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  methods: {
    setAiCatalogFlowToBeAdded(flow = null) {
      this.aiCatalogFlowToBeAdded = flow;
    },
    async deleteFlow(item) {
      const { id, itemType } = item;
      const config = FLOW_TYPE_APOLLO_CONFIG[itemType].delete;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogFlowsQuery],
        });

        const deleteResponse = data[config.responseKey];
        if (!deleteResponse.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to delete flow. %{error}'), {
              error: deleteResponse.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Flow deleted.'));
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

      this.setAiCatalogFlowToBeAdded(null);

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
              sprintf(s__('AICatalog|Could not enable flow: %{flowName}'), {
                flowName: flow.name,
              }),
              ...errors,
            ];
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Flow enabled in %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          sprintf(s__('AICatalog|Could not enable flow in the project. Try again. %{error}'), {
            error,
          }),
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
      :items="aiCatalogFlows"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Delete flow')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
      :delete-fn="deleteFlow"
      :page-info="pageInfo"
      :search="searchTerm"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
    <ai-catalog-item-consumer-modal
      v-if="aiCatalogFlowToBeAdded"
      :item="aiCatalogFlowToBeAdded"
      open
      @submit="addFlowToTarget"
      @hide="setAiCatalogFlowToBeAdded(null)"
    />
  </div>
</template>
