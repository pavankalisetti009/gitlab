<script>
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import updateAiCatalogAgent from '../graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
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
      errors: [],
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
            },
          },
        });

        if (data) {
          const { errors } = data.aiCatalogAgentUpdate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Agent updated.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not update agent. Try again.')];
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
          {{ s__('AICatalog|Modify the agent settings and configuration.') }}
        </div>
      </template>
    </page-heading>
    <ai-catalog-agent-form
      mode="edit"
      :errors="errors"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
