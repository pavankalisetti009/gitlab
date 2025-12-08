<script>
import { GlAlert, GlButton } from '@gitlab/ui';
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
  VERSION_LATEST,
  VERSION_PINNED,
} from 'ee/ai/catalog/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import updateAiCatalogConfiguredItem from '../graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
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
    FoundationalIcon,
    ErrorsAlert,
    PageHeading,
    AiCatalogItemActions,
    AiCatalogItemView,
    GlAlert,
    GlButton,
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
    isFlowsAvailable() {
      return this.glFeatures.aiCatalogFlows;
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    showActions() {
      return this.isGlobal || this.isProjectNamespace;
    },
    isReadyToUpdate() {
      return this.version.activeVersionKey === VERSION_LATEST;
    },
    primaryButtonText() {
      return this.isReadyToUpdate
        ? sprintf(s__('AICatalog|Update to %{version}'), {
            version: this.aiCatalogFlow.latestVersion.humanVersionName,
          })
        : s__('AICatalog|View latest version');
    },
    primaryButtonAction() {
      const target = this.aiCatalogFlow.configurationForProject;
      const updateToVersion = this.aiCatalogFlow.latestVersion.versionName;
      return this.isReadyToUpdate
        ? () => this.updateFlowVersion(target, updateToVersion)
        : () => this.version.setActiveVersionKey(VERSION_LATEST);
    },
    secondaryButtonText() {
      return this.isReadyToUpdate ? s__('AICatalog|View enabled version') : null;
    },
    secondaryButtonAction() {
      return this.isReadyToUpdate ? () => this.version.setActiveVersionKey(VERSION_PINNED) : null;
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
        parentItemConsumerId: this.aiCatalogFlow.configurationForGroup?.id,
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
            this.errorTitle = s__('AICatalog|Could not enable flow');
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
    async updateFlowVersion(target /* ItemConsumer */, pinnedVersionPrefix) {
      if (!this.version.isUpdateAvailable) return;

      const input = {
        id: target.id,
        pinnedVersionPrefix,
      };

      const targetType = target.groupId
        ? AI_CATALOG_CONSUMER_TYPE_GROUP
        : AI_CATALOG_CONSUMER_TYPE_PROJECT;
      const targetTypeLabel = AI_CATALOG_CONSUMER_LABELS[targetType];

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogConfiguredItem,
          variables: {
            input,
          },
          refetchQueries: [aiCatalogFlowQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerUpdate;
          if (errors.length > 0) {
            this.errorTitle = s__('AICatalog|Could not update flow.');
            this.errors = errors;
            return;
          }

          const newVersion = data.aiCatalogItemConsumerUpdate.itemConsumer.pinnedVersionPrefix;
          this.version.setActiveVersionKey(VERSION_PINNED); // reset for the next update
          this.$toast.show(
            sprintf(s__('AICatalog|Flow is now at version %{newVersion}.'), { newVersion }),
          );
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(s__('AICatalog|Could not update flow in the %{target}.'), {
            target: targetTypeLabel,
          }),
        ];
        Sentry.captureException(error);
      }
    },
    async deleteFlow(forceHardDelete) {
      const { id, itemType } = this.aiCatalogFlow;
      const config = FLOW_TYPE_APOLLO_CONFIG[itemType].delete;

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
        <div class="gl-flex gl-gap-3">
          <span class="gl-line-clamp-1 gl-wrap-anywhere">
            {{ aiCatalogFlow.name }}
          </span>
          <foundational-icon
            v-if="aiCatalogFlow.foundational"
            :resource-id="aiCatalogFlow.id"
            :item-type="aiCatalogFlow.itemType"
          />
        </div>
      </template>
      <template v-if="version.isUpdateAvailable" #description>
        <gl-alert
          :dismissible="false"
          :title="s__('AICatalog|A new version is available')"
          class="gl-mt-4"
        >
          <div class="gl-my-3 gl-flex gl-flex-col gl-gap-4">
            <span>{{
              s__(
                'AICatalog|Only this flow in this project will be updated. Other projects using this flow will not be affected.',
              )
            }}</span>
            <div class="gl-flex gl-w-min gl-flex-col gl-gap-4 @sm:gl-flex-row">
              <gl-button
                v-if="secondaryButtonText"
                data-testid="flows-show-secondary-button"
                @click="secondaryButtonAction"
                >{{ secondaryButtonText }}</gl-button
              >
              <gl-button
                variant="confirm"
                data-testid="flows-show-primary-button"
                @click="primaryButtonAction"
                >{{ primaryButtonText }}</gl-button
              >
            </div>
          </div>
        </gl-alert>
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogFlow"
          :item-routes="$options.itemRoutes"
          :is-flows-available="isFlowsAvailable"
          :has-parent-consumer="hasParentConsumer"
          :disable-fn="disableFlow"
          :delete-fn="deleteFlow"
          :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
          :disable-confirm-message="
            s__(
              'AICatalog|Are you sure you want to disable flow %{name}? The flow, its service account, and any associated triggers will no longer work in this project.',
            )
          "
          @add-to-target="addFlowToTarget"
          @report-item="reportFlow"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogFlow" :version-key="version.activeVersionKey" />
  </div>
</template>
