<script>
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsDuplicate',
  components: {
    AiCatalogAgentForm,
    PageHeading,
  },
  data() {
    return {
      errorMessages: [],
      isSubmitting: false,
      originalAgent: {},
      isLoading: true,
    };
  },
  computed: {
    agentId() {
      return this.$route.params.id;
    },
    initialValues() {
      if (!this.originalAgent || !this.originalAgent.id) {
        return {};
      }

      return {
        name: `${s__('AICatalog|Copy of')} ${this.originalAgent.name}`,
        description: this.originalAgent.description,
        systemPrompt: this.originalAgent.latestVersion?.systemPrompt || '',
        userPrompt: this.originalAgent.latestVersion?.userPrompt || '',
        tools: this.originalAgent.latestVersion?.tools?.nodes.map((t) => t.id) || [],
      };
    },
  },
  apollo: {
    originalAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        return { id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.agentId) };
      },
      update(data) {
        this.isLoading = false;
        return data?.aiCatalogItem || {};
      },
      error(error) {
        this.isLoading = false;
        Sentry.captureException(error);
      },
    },
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
            this.errorMessages = errors;
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
        this.errorMessages = [
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
      this.errorMessages = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Duplicate agent')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Duplicate this agent with all its settings and configuration.') }}
        </div>
      </template>
    </page-heading>

    <ai-catalog-agent-form
      mode="create"
      :is-loading="isLoading || isSubmitting"
      :errors="errorMessages"
      :initial-values="initialValues"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
