<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton, GlTabs, GlTab } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import { AGENT_VISIBILITY_LEVEL_DESCRIPTIONS, PAGE_SIZE } from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  VISIBILITY_LEVEL_PRIVATE_STRING,
  VISIBILITY_LEVEL_PUBLIC_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import projectAiCatalogAgentsQuery from '../../graphql/queries/get_project_agents.query.graphql';

export default {
  name: 'AiAgentsIndex',
  components: {
    GlButton,
    GlTabs,
    GlTab,
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
      query: projectAiCatalogAgentsQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          enabled: this.enabled,
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          ...this.paginationVariables,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.project?.aiCatalogItems?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.project?.aiCatalogItems?.pageInfo || {};
      },
      error() {
        this.errors = [s__('AICatalog|There was a problem fetching agents.')];
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
      enabled: true,
      paginationVariables: {
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      },
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiAgents.loading;
    },
    exploreHref() {
      return `${this.exploreAiCatalogPath}${AI_CATALOG_AGENTS_ROUTE}`;
    },
    itemTypeConfig() {
      return {
        disableActionItem: {
          showActionItem: () =>
            (this.userPermissions?.adminAiCatalogItemConsumer && this.enabled) || false,
          text: __('Disable'),
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
    disableConfirmMessage() {
      return s__(
        'AICatalog|Are you sure you want to disable agent %{name}? The agent and any associated flows, triggers, and service accounts will no longer work in this project.',
      );
    },
  },
  methods: {
    async disableAgent(item) {
      const { id } = item.configurationForProject;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
          refetchQueries: [projectAiCatalogAgentsQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to disable agent. %{error}'), {
              error: data.aiCatalogItemConsumerDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Agent disabled in this project.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to disable agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    resetPagination() {
      this.paginationVariables = {
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      };
    },
    handleNextPage() {
      this.paginationVariables = {
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      };
    },
    handlePrevPage() {
      this.paginationVariables = {
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      };
    },
    onTabClick(tab) {
      if (this.enabled !== tab.value) {
        this.enabled = tab.value;
        this.resetPagination();
      }
    },
  },
  tabs: [
    {
      text: __('Enabled'),
      value: true,
    },
    {
      text: s__('AICatalog|Managed'),
      value: false,
    },
  ],
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

    <gl-tabs content-class="gl-py-0">
      <gl-tab
        v-for="tab in $options.tabs"
        :key="tab.text"
        :title="tab.text"
        @click="onTabClick(tab)"
      />
    </gl-tabs>

    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiAgents"
      :item-type-config="itemTypeConfig"
      :disable-confirm-title="s__('AICatalog|Disable agent in this project')"
      :disable-confirm-message="disableConfirmMessage"
      :disable-fn="disableAgent"
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
