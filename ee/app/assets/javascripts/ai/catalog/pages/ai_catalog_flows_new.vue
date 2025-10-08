<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogFlow from '../graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from '../graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsNew',
  components: {
    AiCatalogFlowForm,
    PageHeading,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    isThirdPartyFlowsAvailable() {
      return this.glFeatures.aiCatalogThirdPartyFlows;
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const isThirdPartyFlow = this.isThirdPartyFlowsAvailable && input.definition;
      const createQuery = isThirdPartyFlow ? createAiCatalogThirdPartyFlow : createAiCatalogFlow;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createQuery,
          variables: {
            input,
          },
        });

        if (data) {
          const createResponse = isThirdPartyFlow
            ? data.aiCatalogThirdPartyFlowCreate
            : data.aiCatalogFlowCreate;
          const { errors } = createResponse;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const newFlowId = getIdFromGraphQLId(createResponse.item.id);
          this.$toast.show(s__('AICatalog|Flow created successfully.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: newFlowId },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|The flow could not be added. Try again.')];
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
    <page-heading :heading="s__('AICatalog|New flow')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Connect AI agents to automate complicated tasks.') }}
        </div>
      </template>
    </page-heading>

    <ai-catalog-flow-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
