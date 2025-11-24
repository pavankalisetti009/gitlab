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
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
} from 'ee/ai/catalog/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import reportAiCatalogItem from '../graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import deleteAiCatalogItemConsumer from '../graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
} from '../router/constants';

export default {
  name: 'AiCatalogAgentsShow',
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
    aiCatalogAgent: {
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
    isAgentsAvailable() {
      return this.glFeatures.aiCatalogAgents;
    },
    agentName() {
      return this.aiCatalogAgent.name;
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    showActions() {
      return this.isGlobal || this.isProjectNamespace;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  methods: {
    async addAgentToTarget(target) {
      const input = {
        itemId: this.aiCatalogAgent.id,
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
          refetchQueries: [aiCatalogAgentQuery],
        });

        if (data) {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            this.errorTitle = sprintf(s__('AICatalog|Could not enable agent: %{agentName}'), {
              agentName: this.aiCatalogAgent.name,
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
    async deleteAgent() {
      const { id } = this.aiCatalogAgent;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogAgentMutation,
          variables: {
            id,
          },
        });

        if (!data.aiCatalogAgentDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
              error: data.aiCatalogAgentDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Agent deleted.'));
        this.$router.push({
          name: AI_CATALOG_AGENTS_ROUTE,
        });
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    async disableAgent() {
      const { id } = this.aiCatalogAgent.configurationForProject;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
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
        this.$router.push({
          name: AI_CATALOG_AGENTS_ROUTE,
        });
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to disable agent. %{error}'), { error })];
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
          this.errors = data.aiCatalogItemReport.errors;
          return;
        }

        this.$toast.show(s__('AICatalog|Report submitted successfully.'));
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to report agent. %{error}'), { error })];
        Sentry.captureException(error);
      }
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
    },
  },
  itemRoutes: {
    duplicate: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
    edit: AI_CATALOG_AGENTS_EDIT_ROUTE,
  },
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <page-heading>
      <template #heading>
        <span class="gl-line-clamp-1 gl-wrap-anywhere">
          {{ agentName }}
        </span>
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogAgent"
          :item-routes="$options.itemRoutes"
          :is-agents-available="isAgentsAvailable"
          :disable-fn="disableAgent"
          :delete-fn="deleteAgent"
          :disable-confirm-message="
            s__(
              'AICatalog|Are you sure you want to disable agent %{name}? The agent and any associated flows and triggers will no longer work in this project.',
            )
          "
          @add-to-target="addAgentToTarget"
          @report-item="reportAgent"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogAgent" />
  </div>
</template>
