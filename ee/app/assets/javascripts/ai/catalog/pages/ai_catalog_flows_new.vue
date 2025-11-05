<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import { FLOW_TYPE_APOLLO_CONFIG } from '../constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';
import { prerequisitesPath, prerequisitesError } from '../utils';

export default {
  name: 'AiCatalogFlowsNew',
  components: {
    AiCatalogFlowForm,
    PageHeading,
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  methods: {
    async handleSubmit(input, itemType) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = FLOW_TYPE_APOLLO_CONFIG[itemType].create;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input: {
              ...input,
              addToProjectWhenCreated: true,
            },
          },
        });

        if (data) {
          const createResponse = data[config.responseKey];
          const { errors, item } = createResponse;
          if (errors.length > 0 && item !== null) {
            // created but not added to the project
            createAlert({
              message: s__(
                'AICatalog|Could not enable flow in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
              ),
              messageLinks: {
                link: prerequisitesPath,
              },
            });
          } else if (errors.length > 0 && item === null) {
            // neither created nor added to the project
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
    <page-heading :heading="s__('AICatalog|New flow')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Connect an agent to automate complex tasks') }}
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
