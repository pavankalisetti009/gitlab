<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogFlow from '../graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import { mapSteps } from '../utils';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsDuplicate',
  components: {
    AiCatalogFlowForm,
    PageHeading,
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
      isSubmitting: false,
    };
  },
  computed: {
    flowName() {
      return this.aiCatalogFlow.name;
    },
    initialValues() {
      return {
        name: `${s__('AICatalog|Copy of')} ${this.flowName}`,
        public: false,
        description: this.aiCatalogFlow.description,
        steps: mapSteps(this.aiCatalogFlow.latestVersion.steps),
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogFlow,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors, item } = data.aiCatalogFlowCreate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const newFlowId = getIdFromGraphQLId(item.id);
          this.$toast.show(s__('AICatalog|Flow created successfully.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: newFlowId },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|The flow could not be created. Try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Duplicate flow')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Duplicate this flow with all its settings and configuration.') }}
        </div>
      </template>
    </page-heading>
    <ai-catalog-flow-form
      mode="create"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
