<script>
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  FLOW_TYPE_APOLLO_CONFIG,
  TRACK_EVENT_TYPE_FLOW,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
} from 'ee/ai/catalog/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import reportAiCatalogItem from '../graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogItemConsumer from '../graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
} from '../router/constants';

export default {
  name: 'AiCatalogFlowsShow',
  components: {
    ErrorsAlert,
    PageHeading,
    AiCatalogItemActions,
    AiCatalogItemView,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  inject: {
    isGlobal: {
      default: false,
    },
    projectId: {
      default: null,
    },
  },
  props: {
    aiCatalogFlow: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      errorTitle: null,
    };
  },
  computed: {
    isFlowsAvailable() {
      return this.glFeatures.aiCatalogFlows;
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    flowName() {
      return this.aiCatalogFlow.name;
    },
    showActions() {
      return this.isGlobal || this.isProjectNamespace;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  methods: {
    async addFlowToTarget(target) {
      const input = {
        itemId: this.aiCatalogFlow.id,
        target,
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
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.errorTitle = sprintf(s__('AICatalog|Could not enable flow: %{flowName}'), {
              flowName: this.aiCatalogFlow.name,
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
    async deleteFlow() {
      const { id, itemType } = this.aiCatalogFlow;
      const config = FLOW_TYPE_APOLLO_CONFIG[itemType].delete;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            id,
          },
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
        this.$router.push({
          name: AI_CATALOG_FLOWS_ROUTE,
        });
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete flow. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    async disableFlow() {
      const { id } = this.aiCatalogFlow.configurationForProject;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to disable flow. %{error}'), {
              error: data.aiCatalogItemConsumerDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Flow disabled in this project.'));
        this.$router.push({
          name: AI_CATALOG_FLOWS_ROUTE,
        });
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to disable flow. %{error}'), { error })];
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
          this.errors = data.aiCatalogItemReport.errors;
          return;
        }

        this.$toast.show(s__('AICatalog|Report submitted successfully.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to report flow. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
    },
  },
  itemRoutes: {
    duplicate: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
    edit: AI_CATALOG_FLOWS_EDIT_ROUTE,
  },
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <page-heading>
      <template #heading>
        <span class="gl-line-clamp-1 gl-wrap-anywhere">
          {{ flowName }}
        </span>
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogFlow"
          :item-routes="$options.itemRoutes"
          :is-flows-available="isFlowsAvailable"
          :disable-fn="disableFlow"
          :delete-fn="deleteFlow"
          :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
          :disable-confirm-message="
            s__(
              'AICatalog|Are you sure you want to disable flow %{name}? The flow and associated triggers and service account will no longer work in this project.',
            )
          "
          @add-to-target="addFlowToTarget"
          @report-item="reportFlow"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogFlow" />
  </div>
</template>
