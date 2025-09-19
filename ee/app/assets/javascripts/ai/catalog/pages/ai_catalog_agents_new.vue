<script>
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

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
          const { errors } = data.aiCatalogAgentCreate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const newAgentId = getIdFromGraphQLId(data.aiCatalogAgentCreate.item.id);
          this.$toast.show(s__('AICatalog|Agent created successfully.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: newAgentId },
          });
        }
      } catch (error) {
        this.errors = [
          sprintf(
            s__(
              'AICatalog|The agent could not be added to the project. Check that the project meets the %{link_start}prerequisites%{link_end} and try again.',
            ),
            {
              link_start: `<a href="${helpPagePath('user/ai_catalog', {
                anchor: 'prerequisites',
              })}" target="_blank">`,
              link_end: '</a>',
            },
            false,
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
          {{ s__('AICatalog|AI agents complete specialized tasks.') }}
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
