<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import updateAiCatalogFlow from '../graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import { mapSteps } from '../utils';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import { AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';
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
    isThirdPartyFlow() {
      return this.aiCatalogFlow.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    flowName() {
      return this.aiCatalogFlow.name;
    },
    pageTitle() {
      return `${s__('AICatalog|Edit flow')}: ${this.flowName || this.$route.params.id}`;
    },
    initialValues() {
      const configurationField = this.isThirdPartyFlow
        ? { definition: this.aiCatalogFlow.latestVersion?.definition }
        : { steps: mapSteps(this.aiCatalogFlow.latestVersion?.steps) };

      return {
        projectId: this.aiCatalogFlow.project?.id,
        type: this.aiCatalogFlow.itemType,
        name: this.flowName,
        description: this.aiCatalogFlow.description,
        public: this.aiCatalogFlow.public,
        ...configurationField,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { name, description, public: publicValue, steps } = input;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogFlow,
          variables: {
            input: {
              id: this.aiCatalogFlow.id,
              name,
              description,
              public: publicValue,
              steps,
            },
          },
        });

        if (data) {
          const { errors } = data.aiCatalogFlowUpdate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Flow updated successfully.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|The flow could not be updated. Try again.')];
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
