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
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  ENABLE_AGENT_MODAL_TEXTS,
} from 'ee/ai/catalog/constants';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import VersionAlert from '../components/version_alert.vue';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import reportAiCatalogItem from '../graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogItemConsumer from '../graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
} from '../router/constants';
import AiCatalogItemMetadata from '../components/ai_catalog_item_metadata.vue';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    AiCatalogItemMetadata,
    FoundationalIcon,
    ErrorsAlert,
    PageHeading,
    AiCatalogItemActions,
    AiCatalogItemView,
    GlExperimentBadge,
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
    aiCatalogAgent: {
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
      return showBetaBadge.value;
    },
    badgeType() {
      if (this.showBetaBadge) {
        return 'beta';
      }

      return null;
    },
    formattedItemId() {
      return getIdFromGraphQLId(this.aiCatalogAgent.id);
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    showActions() {
      return this.isGlobal || this.isProjectNamespace;
    },
    configuration() {
      return this.isProjectNamespace
        ? this.aiCatalogAgent.configurationForProject
        : this.aiCatalogAgent.configurationForGroup;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  methods: {
    setErrors({ title = null, errors = [] } = {}) {
      this.errorTitle = title;
      this.errors = errors;
    },
    async addAgentToTarget({ target, triggerTypes }) {
      const input = {
        itemId: this.aiCatalogAgent.id,
        target,
        parentItemConsumerId: this.aiCatalogAgent.configurationForGroup?.id,
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
          refetchQueries: [aiCatalogAgentQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.setErrors({
              title: s__('AICatalog|Could not enable agent'),
              errors,
            });
            return;
          }
          const targetData = data.aiCatalogItemConsumerCreate.itemConsumer[targetType];
          if (targetType === AI_CATALOG_CONSUMER_TYPE_GROUP) {
            const href = `${targetData.webUrl}/-/automate/agents/${this.formattedItemId}`;

            this.$toast.show(
              sprintf(s__('AICatalog|Agent enabled in %{targetType}.'), {
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
              sprintf(s__('AICatalog|Agent enabled in %{name}.'), {
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
                'AICatalog|Could not enable agent in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
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
    async deleteAgent(forceHardDelete) {
      const { id, itemType } = this.aiCatalogAgent;
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[itemType].delete;

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
              sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
                error: deleteResponse.errors?.[0],
              }),
            ],
          });
          return;
        }

        const toastMessage = forceHardDelete
          ? s__('AICatalog|Agent deleted.')
          : s__('AICatalog|Agent hidden.');
        this.$toast.show(toastMessage);
        this.$router.push({
          name: AI_CATALOG_AGENTS_ROUTE,
        });
      } catch (error) {
        this.setErrors({
          errors: [sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    async disableAgent() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id: this.configuration.id,
          },
          refetchQueries: [aiCatalogAgentQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.setErrors({
            errors: [
              sprintf(s__('AICatalog|Failed to disable agent. %{error}'), {
                error: data.aiCatalogItemConsumerDelete.errors?.[0],
              }),
            ],
          });
          return;
        }

        this.version.setActiveVersionKey(null); // let the parent re-compute this

        this.$toast.show(s__('AICatalog|Agent disabled in this project.'));
      } catch (error) {
        this.setErrors({
          errors: [sprintf(s__('AICatalog|Failed to disable agent. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    async reportAgent({ reason, body }) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: reportAiCatalogItem,
          variables: {
            input: {
              id: this.aiCatalogAgent.id,
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
          errors: [sprintf(s__('AICatalog|Failed to report agent. %{error}'), { error })],
        });
        Sentry.captureException(error);
      }
    },
    dismissErrors() {
      this.setErrors();
    },
  },
  itemRoutes: {
    duplicate: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
    edit: AI_CATALOG_AGENTS_EDIT_ROUTE,
  },
  modalTexts: ENABLE_AGENT_MODAL_TEXTS,
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-baseline gl-gap-3">
          <span class="gl-line-clamp-1 gl-wrap-anywhere">
            {{ aiCatalogAgent.name }}
          </span>
          <gl-experiment-badge v-if="badgeType" :type="badgeType" class="gl-self-center" />
          <foundational-icon
            v-if="aiCatalogAgent.foundational"
            :resource-id="aiCatalogAgent.id"
            :item-type="aiCatalogAgent.itemType"
          />
        </div>
      </template>
      <template #description>
        <ai-catalog-item-metadata :item="aiCatalogAgent" :version-key="version.activeVersionKey" />
        <p v-if="aiCatalogAgent.description">{{ aiCatalogAgent.description }}</p>
        <version-alert
          v-if="version.isUpdateAvailable"
          :configuration="configuration"
          :item-type="aiCatalogAgent.itemType"
          :latest-version="aiCatalogAgent.latestVersion"
          :version="version"
          class="gl-mt-4"
          @error="setErrors"
        />
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogAgent"
          :item-routes="$options.itemRoutes"
          :has-parent-consumer="hasParentConsumer"
          :disable-fn="disableAgent"
          :delete-fn="deleteAgent"
          :disable-confirm-message="
            s__(
              'AICatalog|Are you sure you want to disable agent %{name}? The agent will no longer work in this project.',
            )
          "
          :enable-modal-texts="$options.modalTexts"
          @add-to-target="addAgentToTarget"
          @report-item="reportAgent"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogAgent" :version-key="version.activeVersionKey" />
  </div>
</template>
