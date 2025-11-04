<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_TYPE_AGENT,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
} from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  VISIBILITY_LEVEL_PRIVATE_STRING,
  VISIBILITY_LEVEL_PUBLIC_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';

export default {
  name: 'AiAgentsIndex',
  components: {
    GlButton,
    ResourceListsEmptyState,
    ErrorsAlert,
    AiCatalogList,
    AiCatalogListHeader,
  },
  inject: {
    projectId: {
      default: null,
    },
    projectPath: {
      default: null,
    },
    exploreAiCatalogPath: {
      default: '',
    },
  },
  apollo: {
    aiAgents: {
      query: aiCatalogConfiguredItemsQuery,
      variables() {
        return {
          itemTypes: [AI_CATALOG_TYPE_AGENT],
          includeInherited: false,
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
    userPermissions: {
      query: aiCatalogProjectUserPermissionsQuery,
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.project?.userPermissions || {},
    },
  },
  data() {
    return {
      aiAgents: [],
      userPermissions: {},
      errors: [],
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiAgents.loading;
    },
    exploreHref() {
      return `${this.exploreAiCatalogPath}${AI_CATALOG_AGENTS_ROUTE}`;
    },
    items() {
      return this.aiAgents.map((agent) => {
        const { item, ...itemConsumerData } = agent;
        return {
          ...item,
          itemConsumer: itemConsumerData,
        };
      });
    },
    itemTypeConfig() {
      return {
        actionItems: () => [],
        deleteActionItem: {
          showActionItem: () => this.userPermissions?.adminAiCatalogItemConsumer || false,
          text: __('Remove'),
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
  },
  methods: {
    async deleteAgent(item) {
      const { id } = item.itemConsumer;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogConfiguredItemsQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to remove agent. %{error}'), {
              error: data.aiCatalogItemConsumerDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Agent removed from this project.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to remove agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    handleNextPage() {
      this.$apollo.queries.aiAgents.refetch({
        ...this.$apollo.queries.aiAgents.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.aiAgents.refetch({
        ...this.$apollo.queries.aiAgents.variables,
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      });
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div>
    <ai-catalog-list-header
      :heading="s__('AICatalog|Agents')"
      :can-admin="userPermissions.adminAiCatalogItem"
    />

    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <ai-catalog-list
      :is-loading="isLoading"
      :items="items"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="s__('AICatalog|Remove agent from this project')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to remove agent %{name}?')"
      :delete-fn="deleteAgent"
      :page-info="pageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    >
      <template #empty-state>
        <resource-lists-empty-state
          :title="s__('AICatalog|Use agents in your project.')"
          :description="s__('AICatalog|Use agents to automate tasks and answer questions.')"
          :svg-path="$options.EMPTY_SVG_URL"
        >
          <template #actions>
            <gl-button variant="confirm" :href="exploreHref">
              {{ s__('AICatalog|Explore AI Catalog agents') }}
            </gl-button>
          </template>
        </resource-lists-empty-state>
      </template>
    </ai-catalog-list>
  </div>
</template>
