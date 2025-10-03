<script>
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TRACK_EVENT_TYPE_FLOW, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogFlowDetails from '../components/ai_catalog_flow_details.vue';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogFlowMutation from '../graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
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
    AiCatalogFlowDetails,
    AiCatalogItemActions,
  },
  mixins: [InternalEvents.mixin()],
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
    flowName() {
      return this.aiCatalogFlow.name;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: TRACK_EVENT_TYPE_FLOW,
    });
  },
  methods: {
    async addToProject(target) {
      const input = {
        itemId: this.aiCatalogFlow.id,
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
            this.errorTitle = sprintf(s__('AICatalog|Flow could not be added: %{flowName}'), {
              flowName: this.aiCatalogFlow.name,
            });
            this.errors = errors;
            return;
          }

          const name = data.aiCatalogItemConsumerCreate.itemConsumer.project?.name || '';

          this.$toast.show(sprintf(s__('AICatalog|Flow added successfully to %{name}.'), { name }));
        }
      } catch (error) {
        this.errors = [
          sprintf(
            s__('AICatalog|The flow could not be added to the project. Try again. %{error}'),
            { error },
          ),
        ];
        Sentry.captureException(error);
      }
    },
    async deleteFlow() {
      const { id } = this.aiCatalogFlow;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogFlowMutation,
          variables: {
            id,
          },
        });

        if (!data.aiCatalogFlowDelete.success) {
          this.errors = [
            sprintf(s__('AICatalog|Failed to delete flow. %{error}'), {
              error: data.aiCatalogFlowDelete.errors?.[0],
            }),
          ];
          return;
        }

        this.$toast.show(s__('AICatalog|Flow deleted successfully.'));
        this.$router.push({
          name: AI_CATALOG_FLOWS_ROUTE,
        });
      } catch (error) {
        this.errors = [sprintf(s__('AICatalog|Failed to delete flow. %{error}'), { error })];
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
    <page-heading :heading="flowName">
      <template #description>
        {{ aiCatalogFlow.description }}
      </template>
      <template #actions>
        <ai-catalog-item-actions
          :item="aiCatalogFlow"
          :item-routes="$options.itemRoutes"
          :delete-fn="deleteFlow"
          :delete-confirm-title="s__('AICatalog|Delete flow')"
          :delete-confirm-message="s__('AICatalog|Are you sure you want to delete flow %{name}?')"
          @add-to-project="addToProject"
        />
      </template>
    </page-heading>
    <ai-catalog-flow-details :item="aiCatalogFlow" />
  </div>
</template>
