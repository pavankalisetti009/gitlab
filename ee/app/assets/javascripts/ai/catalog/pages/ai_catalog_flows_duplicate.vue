<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { prerequisitesError, resolveVersion } from '../utils';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG, AI_CATALOG_TYPE_FLOW } from '../constants';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsDuplicate',
  components: {
    AiCatalogFlowForm,
    GlExperimentBadge,
    PageHeading,
  },
  inject: {
    isGlobal: {
      default: false,
    },
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
    activeVersion() {
      return resolveVersion(this.aiCatalogFlow, this.isGlobal);
    },
    flowName() {
      return this.aiCatalogFlow.name;
    },
    definition() {
      return this.activeVersion.definition;
    },
    initialValues() {
      return {
        name: `${s__('AICatalog|Copy of')} ${this.flowName}`,
        public: false,
        description: this.aiCatalogFlow.description,
        definition: this.definition,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].create;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input,
          },
        });

        if (data) {
          const createResponse = data[config.responseKey];
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
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not create flow in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
          ),
        ];
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
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          {{ s__('AICatalog|Duplicate flow') }}
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </span>
      </template>
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
