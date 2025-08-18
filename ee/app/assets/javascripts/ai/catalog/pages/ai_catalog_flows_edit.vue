<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import updateAiCatalogFlow from '../graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsEdit',
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
      errorMessages: [],
      isSubmitting: false,
    };
  },
  computed: {
    flowName() {
      return this.aiCatalogFlow.name;
    },
    pageTitle() {
      return `${s__('AICatalog|Edit flow')}: ${this.flowName || this.$route.params.id}`;
    },
    initialValues() {
      return {
        projectId: this.aiCatalogFlow.project?.id,
        name: this.flowName,
        description: this.aiCatalogFlow.description,
        public: this.aiCatalogFlow.public,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { name, description, public: publicValue } = input;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogFlow,
          variables: {
            input: {
              id: this.aiCatalogFlow.id,
              name,
              description,
              public: publicValue,
            },
          },
        });

        if (data) {
          const { errors } = data.aiCatalogFlowUpdate;
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Flow updated successfully.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errorMessages = [s__('AICatalog|The flow could not be updated. Try again.')];
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
    <page-heading :heading="pageTitle">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Modify the flow settings and configuration.') }}
        </div>
      </template>
    </page-heading>
    <ai-catalog-flow-form
      mode="edit"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      :error-messages="errorMessages"
      @dismiss-error="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
