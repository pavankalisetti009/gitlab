<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton, GlModalDirective, GlTabs, GlTab } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
} from 'ee/ai/catalog/constants';
import { createAvailableFlowItemTypes, prerequisitesError } from 'ee/ai/catalog/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
} from 'ee/ai/catalog/router/constants';
import projectAiCatalogFlowsQuery from '../../graphql/queries/get_project_flows.query.graphql';
import AddProjectItemConsumerModal from '../../components/catalog/add_project_item_consumer_modal.vue';
import AiCatalogConfiguredItemsWrapper from '../../components/catalog/ai_catalog_configured_items_wrapper.vue';

export default {
  name: 'AiFlowsIndex',
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
  mixins: [glFeatureFlagsMixin()],
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
    aiFlows: {
      query: projectAiCatalogFlowsQuery,
      skip() {
        return !this.projectPath || this.selectedTabIndex === 0;
      },
      variables() {
        return {
          projectPath: this.projectPath,
          itemTypes: this.itemTypes,
          search: this.searchTerm,
          ...this.paginationVariables,
        };
      },
      // fetchPolicy needed to refresh items after creating an item
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.project?.aiCatalogItems?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.project?.aiCatalogItems?.pageInfo || {};
      },
      error() {
        this.errors = [s__('AICatalog|There was a problem fetching flows.')];
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
      aiFlows: [],
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
      return this.$apollo.queries.aiFlows.loading;
    },
    isFlowsAvailable() {
      return this.glFeatures.aiCatalogFlows;
    },
    itemTypes() {
      return createAvailableFlowItemTypes({
        isFlowsEnabled: this.isFlowsAvailable,
        isThirdPartyFlowsEnabled: this.glFeatures.aiCatalogThirdPartyFlows,
      });
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
    showAddFlow() {
      return this.isProjectNamespace && this.userPermissions?.adminAiCatalogItemConsumer;
    },
    exploreHref() {
      return `${this.exploreAiCatalogPath}${AI_CATALOG_FLOWS_ROUTE}`;
    },
    itemTypeConfig() {
      return {
        showRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
        visibilityTooltip: {
          [VISIBILITY_LEVEL_PUBLIC_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          [VISIBILITY_LEVEL_PRIVATE_STRING]:
            FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
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
    disableConfirmTitle() {
      return sprintf(s__('AICatalog|Disable flow from this %{namespaceType}'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    disableConfirmMessage() {
      if (this.isProjectNamespace) {
        return s__(
          'AICatalog|Are you sure you want to disable flow %{name}? The flow, its service account, and any associated triggers will no longer work in this project.',
        );
      }

      return s__(
        'AICatalog|Are you sure you want to disable flow %{name}? The flow will also be disabled from any projects in this group.',
      );
    },
    emptyStateTitle() {
      return sprintf(s__('AICatalog|Use flows in your %{namespaceType}.'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    emptyStateDescription() {
      return s__('AICatalog|Flows use multiple agents to complete tasks automatically.');
    },
    emptyStateButtonText() {
      return s__('AICatalog|Explore the AI Catalog');
    },
  },
  methods: {
    async addFlowToProject({ itemName, ...input }) {
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
            this.errorTitle = sprintf(s__('AICatalog|Flow "%{name}" could not be enabled.'), {
              name: itemName,
            });
            this.errors = errors;
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer[targetType]?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Flow enabled in %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not enable flow in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
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
  },
  addFlowModalId: 'add-flow-to-project-modal',
  modalTexts: {
    title: s__('AICatalog|Enable flow from group'),
    label: s__('AICatalog|Flow'),
    labelDescription: s__('AICatalog|Only flows enabled in your top-level group are shown.'),
    invalidFeedback: s__('AICatalog|Flow is required.'),
    error: s__('AICatalog|Failed to load group flows'),
    dropdownTexts: {
      placeholder: s__('AICatalog|Select a flow'),
      itemSublabel: s__('AICatalog|Flow ID: %{id}'),
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div>
    <ai-catalog-list-header
      :heading="s__('AICatalog|Flows')"
      :can-admin="userPermissions.adminAiCatalogItem"
      new-button-variant="default"
    >
      <template v-if="isFlowsAvailable" #nav-actions>
        <gl-button v-if="showAddFlow" v-gl-modal="$options.addFlowModalId" variant="confirm">
          {{ s__('AICatalog|Enable flow from group') }}
        </gl-button>
      </template>
    </ai-catalog-list-header>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />

    <gl-tabs v-if="isProjectNamespace" v-model="selectedTabIndex" content-class="gl-py-0">
      <gl-tab :title="__('Enabled')">
        <ai-catalog-configured-items-wrapper
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessage"
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
        <ai-catalog-list-wrapper
          :is-loading="isLoading"
          :items="aiFlows"
          :item-type-config="itemTypeConfig"
          :page-info="pageInfo"
          :empty-state-title="emptyStateTitle"
          :empty-state-description="emptyStateDescription"
          :empty-state-button-href="exploreHref"
          :empty-state-button-text="emptyStateButtonText"
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessage"
          data-testid="managed-flows-list"
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
      :disable-confirm-message="disableConfirmMessage"
      :empty-state-title="emptyStateTitle"
      :empty-state-description="emptyStateDescription"
      :empty-state-button-href="exploreHref"
      :empty-state-button-text="emptyStateButtonText"
      :item-types="itemTypes"
      :item-type-config="itemTypeConfigEnabled"
      @error="handleError"
    />
    <add-project-item-consumer-modal
      v-if="showAddFlow"
      :item-types="itemTypes"
      :modal-id="$options.addFlowModalId"
      :modal-texts="$options.modalTexts"
      show-triggers
      @submit="addFlowToProject"
    />
  </div>
</template>
