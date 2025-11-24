<script>
import { GlButton, GlModalDirective } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
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
import AddProjectItemConsumerModal from '../../components/catalog/add_project_item_consumer_modal.vue';
import AiCatalogConfiguredItemsWrapper from '../../components/catalog/ai_catalog_configured_items_wrapper.vue';

export default {
  name: 'AiFlowsIndex',
  components: {
    GlButton,
    ErrorsAlert,
    AiCatalogListHeader,
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
      groupUserPermissions: {},
      projectUserPermissions: {},
      errors: [],
      errorTitle: null,
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
        disableActionItem: {
          showActionItem: () => this.userPermissions?.adminAiCatalogItemConsumer || false,
          text: __('Disable'),
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
    disableConfirmTitle() {
      return sprintf(s__('AICatalog|Disable flow from this %{namespaceType}'), {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    disableConfirmMessage() {
      if (this.isProjectNamespace) {
        return s__('AICatalog|Are you sure you want to disable flow %{name}?');
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
    <ai-catalog-configured-items-wrapper
      :disable-confirm-title="disableConfirmTitle"
      :disable-confirm-message="disableConfirmMessage"
      :empty-state-title="emptyStateTitle"
      :empty-state-description="
        s__('AICatalog|Flows use multiple agents to complete tasks automatically.')
      "
      :empty-state-button-href="exploreHref"
      :empty-state-button-text="s__('AICatalog|Explore the AI Catalog')"
      :item-types="itemTypes"
      :item-type-config="itemTypeConfig"
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
