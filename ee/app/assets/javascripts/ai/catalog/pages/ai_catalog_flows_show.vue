<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { useAiBetaBadge } from 'ee/ai/duo_agents_platform/composables/use_ai_beta_badge';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG,
  AI_CATALOG_TYPE_FLOW,
  TRACK_EVENT_TYPE_FLOW,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  ENABLE_FLOW_MODAL_TEXTS,
} from 'ee/ai/catalog/constants';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import VersionAlert from '../components/version_alert.vue';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import reportAiCatalogItem from '../graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogItemConsumer from '../graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
} from '../router/constants';
import AiCatalogItemMetadata from '../components/ai_catalog_item_metadata.vue';

export default {
  name: 'AiCatalogFlowsShow',
  components: {
    AiCatalogItemMetadata,
    GlExperimentBadge,
    FoundationalIcon,
    ErrorsAlert,
    PageHeading,
    AiCatalogItemActions,
    AiCatalogItemView,
    VersionAlert,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    isGlobal: {
      default: false,
    },
    projectId: {
      default: null,
    },
    groupId: {
      default: null,
    },
  },
  props: {
    aiCatalogFlow: {
      type: Object,
      required: true,
    },
    version: {
      type: Object,
      required: true,
    },
    hasParentConsumer: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      errors: [],
      errorTitle: null,
    };
  },
  computed: {
    showBetaBadge() {
      const { showBetaBadge } = useAiBetaBadge();
      return showBetaBadge.value || !this.aiCatalogFlow.foundational;
    },
    formattedItemId() {
      return getIdFromGraphQLId(this.aiCatalogFlow.id);
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    showActions() {
      return this.isGlobal || this.isProjectNamespace;
    },
    configuration() {
      return this.isProjectNamespace
        ? this.aiCatalogFlow.configurationForProject
        : this.aiCatalogFlow.configurationForGroup;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  methods: {
    setErrors({ title = null, errors = [] } = {}) {
      this.errorTitle = title;
      this.errors = errors;
    },
    async addFlowToTarget({ target, triggerTypes }) {
      const input = {
        itemId: this.aiCatalogFlow.id,
        target,
        parentItemConsumerId: this.aiCatalogFlow.configurationForGroup?.id,
        triggerTypes,
      };
      const targetType = target.groupId
        ? AI_CATALOG_CONSUMER_TYPE_GROUP
        : AI_CATALOG_CONSUMER_TYPE_PROJECT;
      const targetTypeLabel = AI_CATALOG_CONSUMER_LABELS[targetType];

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogItemConsumer,
          variables: {
            input,
          },
          refetchQueries: [aiCatalogFlowQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.setErrors({
              title: s__('AICatalog|Could not enable flow'),
              errors,
            });
            return;
          }

          const targetData = data.aiCatalogItemConsumerCreate.itemConsumer[targetType];
          if (targetType === AI_CATALOG_CONSUMER_TYPE_GROUP) {
            const href = `${targetData.webUrl}/-/automate/flows/${this.formattedItemId}`;

            this.$toast.show(
              sprintf(s__('AICatalog|Flow enabled in %{targetType}.'), {
                targetType: targetTypeLabel,
              }),
              {
                action: {
                  text: __('View'),
                  href,
                },
              },
            );
          } else {
            this.$toast.show(
              sprintf(s__('AICatalog|Flow enabled in %{name}.'), {
                name: targetData.name,
              }),
            );
          }
        }
      } catch (error) {
        this.setErrors({
          errors: [
            prerequisitesError(
              s__(
                'AICatalog|Could not enable flow in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
              ),
              {
                target: targetTypeLabel,
              },
            ),
          ],
        });
        Sentry.captureException(error);
      }
    },
    async deleteFlow(forceHardDelete) {
      const { id } = this.aiCatalogFlow;
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].delete;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            id,
            forceHardDelete,
          },
        });

        const deleteResponse = data[config.responseKey];
        if (!deleteResponse.success) {
          this.setErrors({
            errors: [
              sprintf(s__('AICatalog|Failed to delete flow. %{error}'), {
                error: deleteResponse.errors?.[0],
              }),
            ],
          });
          return;
        }

        const toastMessage = forceHardDelete
          ? s__('AICatalog|Flow deleted.')
          : s__('AICatalog|Flow hidden.');
        this.$toast.show(toastMessage);
        this.$router.push({
          name: AI_CATALOG_FLOWS_ROUTE,
        });
      } catch (error) {
        this.setErrors({
          errors: [sprintf(s__('AICatalog|Failed to delete flow. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    async disableFlow() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id: this.configuration.id,
          },
          refetchQueries: [aiCatalogFlowQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.setErrors({
            errors: [
              sprintf(s__('AICatalog|Failed to disable flow. %{error}'), {
                error: data.aiCatalogItemConsumerDelete.errors?.[0],
              }),
            ],
          });
          return;
        }

        this.version.setActiveVersionKey(null); // let the parent re-compute this

        this.$toast.show(s__('AICatalog|Flow disabled in this project.'));
      } catch (error) {
        this.setErrors({
          errors: [sprintf(s__('AICatalog|Failed to disable flow. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    async reportFlow({ reason, body }) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: reportAiCatalogItem,
          variables: {
            input: {
              id: this.aiCatalogFlow.id,
              reason,
              body,
            },
          },
        });

        if (data.aiCatalogItemReport.errors?.length > 0) {
          this.setErrors({
            errors: data.aiCatalogItemReport.errors,
          });
          return;
        }

        this.$toast.show(s__('AICatalog|Report submitted successfully.'));
      } catch (error) {
        this.setErrors({
          errors: [sprintf(s__('AICatalog|Failed to report flow. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    dismissErrors() {
      this.setErrors();
    },
  },
  itemRoutes: {
    duplicate: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
    edit: AI_CATALOG_FLOWS_EDIT_ROUTE,
  },
  modalTexts: ENABLE_FLOW_MODAL_TEXTS,
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-baseline gl-gap-3">
          <span class="gl-line-clamp-1 gl-wrap-anywhere">
            {{ aiCatalogFlow.name }}
          </span>
          <gl-experiment-badge v-if="showBetaBadge" type="beta" class="!gl-mx-0 gl-self-center" />
          <foundational-icon
            v-if="aiCatalogFlow.foundational"
            :resource-id="aiCatalogFlow.id"
            :item-type="aiCatalogFlow.itemType"
          />
        </div>
      </template>
      <template #description>
        <ai-catalog-item-metadata :item="aiCatalogFlow" :version-key="version.activeVersionKey" />
        <p v-if="aiCatalogFlow.description">{{ aiCatalogFlow.description }}</p>
        <version-alert
          v-if="version.isUpdateAvailable"
          :configuration="configuration"
          :item-type="aiCatalogFlow.itemType"
          :latest-version="aiCatalogFlow.latestVersion"
          :version="version"
        />
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogFlow"
          :item-routes="$options.itemRoutes"
          :has-parent-consumer="hasParentConsumer"
          :disable-fn="disableFlow"
          :delete-fn="deleteFlow"
          :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
          :disable-confirm-message="
            s__(
              'AICatalog|Are you sure you want to disable flow %{name}? The flow, its service account, and any associated triggers will no longer work in this project.',
            )
          "
          :enable-modal-texts="$options.modalTexts"
          @add-to-target="addFlowToTarget"
          @report-item="reportFlow"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogFlow" :version-key="version.activeVersionKey" />
  </div>
</template>
