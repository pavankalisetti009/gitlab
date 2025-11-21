<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton, GlTabs, GlTab } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import {
  AI_CATALOG_TYPE_AGENT,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
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
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import projectAiCatalogAgentsQuery from '../../graphql/queries/get_project_agents.query.graphql';

export default {
  name: 'AiAgentsIndex',
  components: {
    AiCatalogConfiguredItemsWrapper,
    GlButton,
    GlTabs,
    GlTab,
    ResourceListsEmptyState,
    ErrorsAlert,
    AiCatalogList,
    AiCatalogListHeader,
  },
  inject: {
    groupPath: {
      default: null,
    },
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
      skip() {
        return !this.projectPath || this.selectedTabIndex === 0;
      },
      variables() {
        return {
          projectPath: this.projectPath,
          enabled: false,
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          ...this.paginationVariables,
        };
      },
      update: (data) => data?.project?.aiCatalogItems?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.project?.aiCatalogItems?.pageInfo || {};
      },
      error() {
        this.errors = [s__('AICatalog|There was a problem fetching agents.')];
      },
    },
    groupUserPermissions: {
      query: aiCatalogGroupUserPermissionsQuery,
      skip() {
        return !this.groupPath;
      },
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update: (data) => data.group?.userPermissions || {},
    },
    projectUserPermissions: {
      query: aiCatalogProjectUserPermissionsQuery,
      skip() {
        return !this.projectPath;
      },
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update: (data) => data.project?.userPermissions || {},
    },
  },
  data() {
    return {
      aiAgents: [],
      groupUserPermissions: {},
      projectUserPermissions: {},
      errors: [],
      errorTitle: null,
      pageInfo: {},
      paginationVariables: {
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      },
      selectedTabIndex: 0,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiAgents.loading;
    },
    exploreHref() {
      return `${this.exploreAiCatalogPath}${AI_CATALOG_AGENTS_ROUTE}`;
    },
    itemTypes() {
      return [AI_CATALOG_TYPE_AGENT];
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
    itemTypeConfigEnabled() {
      return {
        disableActionItem: {
          showActionItem: () => this.userPermissions?.adminAiCatalogItemConsumer || false,
          text: __('Disable'),
        },
        ...this.itemTypeConfig,
      };
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    namespaceTypeLabel() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_PROJECT]
        : AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_GROUP];
    },
    userPermissions() {
      return this.isProjectNamespace ? this.projectUserPermissions : this.groupUserPermissions;
    },
    disableConfirmTitle() {
      return sprintf(s__('AICatalog|Disable agent from this %{namespaceType}'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    disableConfirmMessageGroup() {
      return s__(
        'AICatalog|Are you sure you want to disable agent %{name}? The agent will also be disabled from any projects in this group.',
      );
    },
    disableConfirmMessageProject() {
      return s__(
        'AICatalog|Are you sure you want to disable agent %{name}? The agent and any associated flows, triggers, and service accounts will no longer work in this project.',
      );
    },
    emptyStateTitle() {
      return sprintf(s__('AICatalog|Use agents in your %{namespaceType}.'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    emptyStateDescription() {
      return s__('AICatalog|Use agents to automate tasks and answer questions.');
    },
    emptyStateButtonText() {
      return s__('AICatalog|Explore AI Catalog agents');
    },
  },
  methods: {
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
    handleError({ title, errors }) {
      this.errorTitle = title;
      this.errors = errors;
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
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
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />

    <gl-tabs v-if="isProjectNamespace" v-model="selectedTabIndex" content-class="gl-py-0">
      <gl-tab :title="__('Enabled')">
        <ai-catalog-configured-items-wrapper
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessageProject"
          :empty-state-title="emptyStateTitle"
          :empty-state-description="emptyStateDescription"
          :empty-state-button-href="exploreHref"
          :empty-state-button-text="emptyStateButtonText"
          :item-types="itemTypes"
          :item-type-config="itemTypeConfigEnabled"
          @error="handleError"
        />
      </gl-tab>
      <gl-tab :title="s__('AICatalog|Managed')" lazy @click="resetPagination">
        <ai-catalog-list
          :is-loading="isLoading"
          :items="aiAgents"
          :item-type-config="itemTypeConfig"
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessageProject"
          :page-info="pageInfo"
          @next-page="handleNextPage"
          @prev-page="handlePrevPage"
        >
          <template #empty-state>
            <resource-lists-empty-state
              :title="emptyStateTitle"
              :description="emptyStateDescription"
              :svg-path="$options.EMPTY_SVG_URL"
            >
              <template #actions>
                <gl-button variant="confirm" :href="exploreHref">
                  {{ emptyStateButtonText }}
                </gl-button>
              </template>
            </resource-lists-empty-state>
          </template>
        </ai-catalog-list>
      </gl-tab>
    </gl-tabs>
    <ai-catalog-configured-items-wrapper
      v-else
      :disable-confirm-title="disableConfirmTitle"
      :disable-confirm-message="disableConfirmMessageGroup"
      :empty-state-title="emptyStateTitle"
      :empty-state-description="emptyStateDescription"
      :empty-state-button-href="exploreHref"
      :empty-state-button-text="emptyStateButtonText"
      :item-types="itemTypes"
      :item-type-config="itemTypeConfigEnabled"
      @error="handleError"
    />
  </div>
</template>
