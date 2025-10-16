<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';
import createAiCatalogFlow from '../graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from '../graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import { mapSteps } from '../utils';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsDuplicate',
  components: {
    AiCatalogFlowForm,
    PageHeading,
  },
  mixins: [glFeatureFlagsMixin()],
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
    initialValues() {
      const configurationField = this.isThirdPartyFlow
        ? { definition: this.aiCatalogFlow.latestVersion?.definition }
        : { steps: mapSteps(this.aiCatalogFlow.latestVersion?.steps) };

      return {
        type: this.aiCatalogFlow.itemType,
        name: `${s__('AICatalog|Copy of')} ${this.flowName}`,
        public: false,
        description: this.aiCatalogFlow.description,
        ...configurationField,
      };
    },
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
          const { errors, item } = createResponse;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const newFlowId = getIdFromGraphQLId(item.id);
          this.$toast.show(s__('AICatalog|Flow created.'));
          this.$router.push({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: newFlowId },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not create flow. Try again.')];
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
