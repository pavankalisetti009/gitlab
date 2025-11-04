<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlButton, GlModalDirective } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  PAGE_SIZE,
} from 'ee/ai/catalog/constants';
import { createAvailableFlowItemTypes, prerequisitesError } from 'ee/ai/catalog/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
} from 'ee/ai/catalog/router/constants';
import AiCatalogAddFlowToProjectModal from '../../components/catalog/ai_catalog_add_flow_to_project_modal.vue';

export default {
  name: 'AiFlowsIndex',
  components: {
    GlButton,
    ResourceListsEmptyState,
    ErrorsAlert,
    AiCatalogList,
    AiCatalogListHeader,
    AiCatalogAddFlowToProjectModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    groupId: {
      default: null,
    },
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
      query: aiCatalogConfiguredItemsQuery,
      variables() {
        return {
          ...this.namespaceVariables,
          itemTypes: this.itemTypes,
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
    };
  },
  computed: {
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
    namespaceVariables() {
      if (this.isProjectNamespace) {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          includeInherited: false,
        };
      }
      return {
        groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
      };
    },
    userPermissions() {
      return this.isProjectNamespace ? this.projectUserPermissions : this.groupUserPermissions;
    },
    showAddFlow() {
      return this.isProjectNamespace && this.userPermissions?.adminAiCatalogItemConsumer;
    },
    isLoading() {
      return this.$apollo.queries.aiFlows.loading;
    },
    exploreHref() {
      return `${this.exploreAiCatalogPath}${AI_CATALOG_FLOWS_ROUTE}`;
    },
    items() {
      return this.aiFlows.map((flow) => {
        const { item, ...itemConsumerData } = flow;
        return {
          ...item,
          itemConsumer: itemConsumerData,
        };
      });
    },
    itemTypeConfig() {
      return {
        deleteActionItem: {
          showActionItem: () => this.userPermissions?.adminAiCatalogItemConsumer || false,
          text: __('Remove'),
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
    deleteConfirmTitle() {
      return sprintf(s__('AICatalog|Remove flow from this %{namespaceType}'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    emptyStateTitle() {
      return sprintf(s__('AICatalog|Use flows in your %{namespaceType}.'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
  },
  methods: {
    async addFlowToProject(flowAttributes) {
      const { flowName, ...flowInput } = flowAttributes;
      const input = {
        ...flowInput,
        target: {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
        },
      };
      const targetType = AI_CATALOG_CONSUMER_TYPE_PROJECT;
      const targetTypeLabel = AI_CATALOG_CONSUMER_LABELS[targetType];

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogItemConsumer,
          variables: {
            input,
          },
          refetchQueries: [aiCatalogConfiguredItemsQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.errorTitle = sprintf(s__('AICatalog|Could not enable flow: %{flowName}'), {
              flowName,
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
    async deleteFlow(item) {
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
            sprintf(s__('AICatalog|Failed to remove flow. %{error}'), {
              error: data.aiCatalogItemConsumerDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(
          sprintf(s__('AICatalog|Flow removed from this %{namespaceType}.'), {
            namespaceType: this.namespaceTypeLabel,
          }),
        );
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to remove flow. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    handleNextPage() {
      this.$apollo.queries.aiFlows.refetch({
        ...this.$apollo.queries.aiFlows.variables,
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.aiFlows.refetch({
        ...this.$apollo.queries.aiFlows.variables,
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      });
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
    },
  },
  EMPTY_SVG_URL,
  addFlowModalId: 'add-flow-to-project-modal',
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
          {{ s__('AICatalog|Enable flow in project') }}
        </gl-button>
      </template>
    </ai-catalog-list-header>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <ai-catalog-list
      :is-loading="isLoading"
      :items="items"
      :item-type-config="itemTypeConfig"
      :delete-confirm-title="deleteConfirmTitle"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to remove flow %{name}?')"
      :delete-fn="deleteFlow"
      :page-info="pageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    >
      <template #empty-state>
        <resource-lists-empty-state
          :title="emptyStateTitle"
          :description="s__('AICatalog|Flows use multiple agents to complete tasks automatically.')"
          :svg-path="$options.EMPTY_SVG_URL"
        >
          <template #actions>
            <gl-button variant="confirm" :href="exploreHref">
              {{ s__('AICatalog|Explore AI Catalog flows') }}
            </gl-button>
          </template>
        </resource-lists-empty-state>
      </template>
    </ai-catalog-list>
    <ai-catalog-add-flow-to-project-modal
      v-if="showAddFlow"
      :modal-id="$options.addFlowModalId"
      @submit="addFlowToProject"
    />
  </div>
</template>
