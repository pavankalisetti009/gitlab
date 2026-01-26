<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton, GlModalDirective, GlTabs, GlTab } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import { __, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import {
  VISIBILITY_LEVEL_PRIVATE_STRING,
  VISIBILITY_LEVEL_PUBLIC_STRING,
} from '~/visibility_level/constants';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  ENABLE_AGENT_MODAL_TEXTS,
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED,
  TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_PAGE_LIST,
} from 'ee/ai/catalog/constants';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import { prerequisitesError } from 'ee/ai/catalog/utils';
import projectAiCatalogAgentsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_agents.query.graphql';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';

export default {
  name: 'AiAgentsIndex',
  components: {
    GlButton,
    GlTabs,
    GlTab,
    ErrorsAlert,
    AiCatalogListHeader,
    AiCatalogListWrapper,
    AddProjectItemConsumerModal,
    AiCatalogConfiguredItemsWrapper,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
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
    rootGroupId: {
      default: null,
    },
    groupId: {
      default: null,
    },
  },
  apollo: {
    aiAgents: {
      query: projectAiCatalogAgentsQuery,
      skip() {
        return !this.projectPath || this.selectedTabIndex === 0;
      },
      variables() {
        const effectiveGroupId = this.projectId ? this.rootGroupId : this.groupId;

        return {
          projectPath: this.projectPath,
          itemTypes: this.itemTypes,
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          groupId: convertToGraphQLId(TYPENAME_GROUP, effectiveGroupId),
          search: this.searchTerm,
          ...this.paginationVariables,
        };
      },
      // fetchPolicy needed to refresh items after creating an item
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => {
        return (data?.project?.aiCatalogItems?.nodes || []).map((item) => {
          if (!item.configurationForProject) {
            return item;
          }

          const latest = item.latestVersion.humanVersionName;
          const pinned = item.configurationForProject?.pinnedItemVersion.humanVersionName;

          return {
            ...item,
            isUpdateAvailable: latest !== pinned,
          };
        });
      },
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
      searchTerm: '',
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
      const types = [AI_CATALOG_TYPE_AGENT];

      if (this.glFeatures.aiCatalogThirdPartyFlows) {
        types.push(AI_CATALOG_TYPE_THIRD_PARTY_FLOW);
      }
      return types;
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
    itemTypeConfigManaged() {
      return {
        showStatusBadge: true,
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
    showAddAgent() {
      return this.isProjectNamespace && this.userPermissions?.adminAiCatalogItemConsumer;
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
        'AICatalog|Are you sure you want to disable agent %{name}? The agent will no longer work in this project.',
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
      return s__('AICatalog|Explore the AI Catalog');
    },
  },
  methods: {
    async addAgentToProject({ itemName, ...input }) {
      const targetType = AI_CATALOG_CONSUMER_TYPE_PROJECT;
      const targetTypeLabel = AI_CATALOG_CONSUMER_LABELS[targetType];

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogItemConsumer,
          variables: {
            input: {
              ...input,
              target: {
                projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
              },
            },
          },
          refetchQueries: [aiCatalogConfiguredItemsQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.errorTitle = sprintf(s__('AICatalog|Agent "%{name}" could not be enabled.'), {
              name: itemName,
            });
            this.errors = errors;
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer[targetType]?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Agent enabled in %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not enable agent in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
            {
              target: targetTypeLabel,
            },
          ),
        ];
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
    handleSearch(filters) {
      [this.searchTerm] = filters;
    },
    handleClearSearch() {
      this.searchTerm = '';
    },
    handleError({ title, errors }) {
      this.errorTitle = title;
      this.errors = errors;
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
    },
    onClickManagedTab() {
      this.resetPagination();
      if (this.selectedTabIndex !== 1) {
        this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED, {
          label: TRACK_EVENT_TYPE_AGENT,
        });
      }
    },
    onClickEnable() {
      this.trackEvent(TRACK_EVENT_ENABLE_AI_CATALOG_ITEM, {
        label: TRACK_EVENT_TYPE_AGENT,
        origin: TRACK_EVENT_ORIGIN_PROJECT,
        page: TRACK_EVENT_PAGE_LIST,
      });
    },
  },
  addAgentModalId: 'add-agent-to-project-modal',
  modalTexts: ENABLE_AGENT_MODAL_TEXTS,
  EMPTY_SVG_URL,
};
</script>

<template>
  <div>
    <ai-catalog-list-header
      :heading="s__('AICatalog|Agents')"
      :can-admin="userPermissions.adminAiCatalogItem"
      new-button-variant="default"
    >
      <template #nav-actions>
        <gl-button
          v-if="showAddAgent"
          v-gl-modal="$options.addAgentModalId"
          variant="confirm"
          data-testid="enable-agent-button"
          @click="onClickEnable"
        >
          {{ s__('AICatalog|Enable agent from group') }}
        </gl-button>
      </template>
    </ai-catalog-list-header>
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
      <gl-tab :title="s__('AICatalog|Managed')" lazy @click="onClickManagedTab">
        <ai-catalog-list-wrapper
          :is-loading="isLoading"
          :items="aiAgents"
          :item-type-config="itemTypeConfigManaged"
          :page-info="pageInfo"
          :empty-state-title="emptyStateTitle"
          :empty-state-description="emptyStateDescription"
          :empty-state-button-href="exploreHref"
          :empty-state-button-text="emptyStateButtonText"
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessageProject"
          :search-term="searchTerm"
          data-testid="managed-agents-list"
          @next-page="handleNextPage"
          @prev-page="handlePrevPage"
          @search="handleSearch"
          @clear-search="handleClearSearch"
        />
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
    <add-project-item-consumer-modal
      v-if="showAddAgent"
      :item-types="itemTypes"
      :modal-id="$options.addAgentModalId"
      :modal-texts="$options.modalTexts"
      @submit="addAgentToProject"
    />
  </div>
</template>
