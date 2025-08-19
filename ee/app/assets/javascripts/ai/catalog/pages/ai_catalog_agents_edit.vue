<script>
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import updateAiCatalogAgent from '../graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsEdit',
  components: {
    AiCatalogAgentForm,
    PageHeading,
  },
  props: {
    aiCatalogAgent: {
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
    agentName() {
      return this.aiCatalogAgent.name;
    },
    pageTitle() {
      return `${s__('AICatalog|Edit agent')}: ${this.agentName || this.$route.params.id}`;
    },
    initialValues() {
      return {
        projectId: this.aiCatalogAgent.project?.id,
        name: this.agentName,
        description: this.aiCatalogAgent.description,
        systemPrompt: this.aiCatalogAgent.latestVersion?.systemPrompt,
        userPrompt: this.aiCatalogAgent.latestVersion?.userPrompt,
        public: this.aiCatalogAgent.public,
        tools: this.aiCatalogAgent.latestVersion?.tools?.nodes.map((t) => t.id) || [],
      };
    },
  },
  methods: {
    async handleSubmit(formValues) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogAgent,
          variables: {
            input: {
              ...formValues,
              id: this.aiCatalogAgent.id,
              projectId: undefined,
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
        this.errorMessages = [s__('AICatalog|The agent could not be updated. Try again.')];
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
          {{ s__('AICatalog|Modify the agent settings and configuration.') }}
        </div>
      </template>
    </page-heading>
    <ai-catalog-agent-form
      mode="edit"
      :error-messages="errorMessages"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      @dismiss-error="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
