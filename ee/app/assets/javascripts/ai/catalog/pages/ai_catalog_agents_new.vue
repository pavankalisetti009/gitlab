<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { prerequisitesPath, prerequisitesError } from '../utils';

export default {
  name: 'AiCatalogAgentsNew',
  components: {
    AiCatalogAgentForm,
    PageHeading,
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogAgent,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors, item } = data.aiCatalogAgentCreate;
          if (errors.length > 0 && item !== null) {
            // created but not added to the project
            createAlert({
              message: s__(
                'AICatalog|Could not enable agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
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

          const newAgentId = getIdFromGraphQLId(item.id);
          this.$toast.show(s__('AICatalog|Agent created.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: newAgentId },
          });
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not create agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
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
    <page-heading :heading="s__('AICatalog|New agent')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{
            s__(
              'AICatalog|Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
            )
          }}
        </div>
      </template>
    </page-heading>

    <ai-catalog-agent-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
