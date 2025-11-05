<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import { FLOW_TYPE_APOLLO_CONFIG } from '../constants';
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
      errors: [],
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
        type: this.aiCatalogFlow.itemType,
        name: this.flowName,
        description: this.aiCatalogFlow.description,
        public: this.aiCatalogFlow.public,
        definition: this.aiCatalogFlow.latestVersion.definition,
      };
    },
  },
  methods: {
    async handleSubmit({ itemType, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = FLOW_TYPE_APOLLO_CONFIG[this.aiCatalogFlow.itemType].update;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input: {
              id: this.aiCatalogFlow.id,
              ...input,
            },
          },
        });

        if (data) {
          const { errors } = data[config.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Flow updated.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not update flow. Try again.')];
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
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
