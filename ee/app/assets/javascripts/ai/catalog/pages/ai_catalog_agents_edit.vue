<script>
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import updateAiCatalogAgent from '../graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { TYPENAME_AI_CATALOG_ITEM } from '../constants';

export default {
  name: 'AiCatalogAgentsEdit',
  components: {
    AiCatalogAgentForm,
    PageHeading,
  },
  apollo: {
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      update(data) {
        return data?.aiCatalogItem;
      },
      result(res) {
        this.onAgentQueryResult(res);
      },
    },
  },
  data() {
    return {
      aiCatalogAgent: null,
      errorMessages: [],
      isSubmitting: false,
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent?.name || '';
    },
    agentSystemPrompt() {
      return this.aiCatalogAgent?.versions?.nodes?.[0]?.systemPrompt;
    },
    agentUserPrompt() {
      return this.aiCatalogAgent?.versions?.nodes?.[0]?.userPrompt;
    },
    pageTitle() {
      return `${s__('AICatalog|Edit agent')}: ${this.agentName}`;
    },
    initialValues() {
      return {
        projectId: this.aiCatalogAgent?.project.id || null,
        name: this.agentName,
        description: this.aiCatalogAgent?.description || '',
        systemPrompt: this.agentSystemPrompt,
        userPrompt: this.agentUserPrompt,
        public: this.aiCatalogAgent?.public || false,
      };
    },
  },
  methods: {
    onAgentQueryResult({ data }) {
      if (!data || !data.aiCatalogItem) {
        const queryError = new Error(
          `Agent not found: Failed to query agent with ID ${this.$route.params.id}`,
        );
        Sentry.captureException(queryError);
        this.$router.push({ name: AI_CATALOG_AGENTS_ROUTE });
      }
    },
    async handleSubmit(formValues) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { name, description, userPrompt, systemPrompt } = formValues;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogAgent,
          variables: {
            input: {
              id: this.aiCatalogAgent.id,
              name,
              description,
              userPrompt,
              systemPrompt,
              public: formValues.public,
            },
          },
        });

        if (data) {
          const { errors } = data.aiCatalogAgentUpdate;
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Agent updated successfully.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errorMessages = [s__('AICatalog|The agent could not be updated. Please try again.')];
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
  <div v-if="aiCatalogAgent">
    <page-heading :heading="pageTitle" />
    <p>
      {{ s__('AICatalog|Modify the agent settings and configuration.') }}
    </p>
    <ai-catalog-agent-form
      v-if="aiCatalogAgent"
      mode="edit"
      :error-messages="errorMessages"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      @dismiss-error="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
