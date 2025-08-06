<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogFlow from '../graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsNew',
  components: {
    AiCatalogFlowForm,
    PageHeading,
  },
  data() {
    return {
      errorMessages: [],
      isSubmitting: false,
    };
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
          const { errors } = data.aiCatalogFlowCreate;
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          const newFlowId = getIdFromGraphQLId(data.aiCatalogFlowCreate.item.id);
          this.$toast.show(s__('AICatalog|Flow created successfully.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: newFlowId },
          });
        }
      } catch (error) {
        this.errorMessages = [s__('AICatalog|The flow could not be added. Please try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|New flow')" />

    <ai-catalog-flow-form
      mode="create"
      :is-loading="isSubmitting"
      :error-messages="errorMessages"
      @dismiss-error="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
