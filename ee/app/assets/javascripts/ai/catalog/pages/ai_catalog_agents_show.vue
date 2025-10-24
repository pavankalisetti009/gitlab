<script>
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TRACK_EVENT_TYPE_AGENT, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { prerequisitesError } from '../utils';
import AiCatalogItemMetadata from '../components/ai_catalog_item_metadata.vue';
import AiCatalogAgentDetails from '../components/ai_catalog_agent_details.vue';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
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
    AiCatalogItemMetadata,
    AiCatalogAgentDetails,
    AiCatalogItemActions,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  inject: {
    isGlobal: {
      default: false,
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
    agentName() {
      return this.aiCatalogAgent.name;
    },
    showActions() {
      return this.isGlobal || this.glFeatures.aiCatalogItemProjectCuration;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_AGENT,
    });
  },
  methods: {
    async addToProject(target) {
      const input = {
        itemId: this.aiCatalogAgent.id,
        target,
      };

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
            this.errorTitle = sprintf(s__('AICatalog|Could not enable agent: %{agentName}'), {
              agentName: this.aiCatalogAgent.name,
            });
            this.errors = errors;
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Agent enabled in %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not enable agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
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
    <page-heading :heading="agentName">
      <template #description>
        {{ aiCatalogAgent.description }}
      </template>
      <template #actions>
        <ai-catalog-item-actions
          v-if="showActions"
          :item="aiCatalogAgent"
          :item-routes="$options.itemRoutes"
          :delete-fn="deleteAgent"
          :delete-confirm-title="s__('AICatalog|Delete agent')"
          :delete-confirm-message="s__('AICatalog|Are you sure you want to delete agent %{name}?')"
          @add-to-project="addToProject"
        />
      </template>
    </page-heading>
    <div class="gl-flex gl-flex-col gl-gap-5 @md:gl-flex-row">
      <ai-catalog-agent-details :item="aiCatalogAgent" class="gl-grow" />
      <ai-catalog-item-metadata :item="aiCatalogAgent" class="gl-shrink-0" />
    </div>
  </div>
</template>
